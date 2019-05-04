##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

#!/usr/bin/env ruby

# basic check of asf/pit-auth consistency

# - name agrees with ldap query
# - incorrect alias reference

# allowable non-LDAP names
ROLE_NAMES =
  %w(buildbot comdev_role projects_role spamassassin_role svn-role acrequser whimsysvn apezmlm puppetsvn apsiteread apsecmail apezmlm smtpd svn rptremind comdev-svn openejb-tck staff
  sk clr uli nick jim upayavira cpluchino mostarda druggeri
  svn-site-role
)

DIR = ARGV.first || '/srv/git/infrastructure-puppet/modules/subversion_server/files/authorization'

def parse(file)
  puts "Parsing #{file}"
  section=''
  names=Hash.new(0)
  IO.foreach(file) { |x|
    x.chomp!
    next if x =~ /^(#| *$)/
    section='groups' and next if x =~ /^\[groups\]$/
    section='paths'  and next if x =~ /^\[\/\]$/
    if section == 'groups'
      if x =~ /^(\w[^=]+)={ldap:cn=(\w[^,]+),([^}]+)}/
        a,b,c = $1,$2,$3
        names[a]+=1
        suff=''
        # ou=pmc only needed for tac and security now
        if c =~ /^ou=pmc,ou=committees/ or c =~ /ou=project,[^;]+;attr=owner/
          suff='-p?pmc'
        end
        ma=%r{^#{b}#{suff}$}
        puts "Mis-matched names: #{x} #{a} != #{ma}" unless a =~ ma
#        die
        next
      end
      if x =~ /^(\w[^=]+)={reuse:(asf|pit)-authorization:(\w[^}]+)}$/
        names[$1]+=1
        puts "Mis-matched names: #{x} #{$1} != #{$3}" unless $1 == $3
        next
      end
      if x =~ /^([-\w]+)=(\w.*)?$/
        names[$1]+=1
        next
      end
    elsif section == 'paths'
      next if x =~ /^\[((asf:|infra:|private:|bigdata:)?\/\S*)\]$/ # [/path]
      if x =~ /^(?:@(\S+)|\*|(\S+)) *= *r?w? *$/
        if $1
          puts "Undefined name: '#{$1}' in #{x}" unless names.has_key?($1)
          next
        end
        next unless $2
        next if ROLE_NAMES.include? $2
        p "Unexpected name: #{x}"
        next
      end
    else
      p "Unexpected section: #{section}"
    end
   p "Unexpected line: #{x}"
  }
  names.each() do |k,v|
    puts "Duplicate Key: #{k} Count: #{v}" unless v == 1 
  end   
  puts "Completed validation"
end
parse("#{DIR}/asf-authorization-template")
parse("#{DIR}/pit-authorization-template")
