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

#
# File an additional ICLA:
#  - [optional] move existing ICLA into a directory
#  - add files to (new) documents/iclas dirctory
#  - modify officers/iclas.txt entry
#  - respond to original email
#

# extract message
message = Mailbox.find(@message)

# find person
person = ASF::Person.find(@id)

# extract file extension
fileext = File.extname(@selected).downcase if @signature.empty?

# obtain per-user information
_personalize_email(env.user)

########################################################################
#                        move existing document                        #
########################################################################

iclas = ASF::SVN['iclas'].untaint
@filename.untaint if @filename =~ /\A\w[-.\w]*\z/

if not Dir.exist? "#{iclas}/#@filename"
  @existing = File.basename(Dir["#{iclas}/#@filename.*"].first)
  task "svn mv #@existing #@filename/icla#{File.extname(@existing)}" do
    form do
      _input value: @existing, name: 'existing'
    end

    complete do |dir|
      # checkout empty officers directory
      svn 'checkout', '--depth', 'empty',
        'https://svn.apache.org/repos/private/documents/iclas', "#{dir}/iclas"

      # update file to be moved
      svn 'update', "#{dir}/iclas/#{@existing}"

      # create target directory
      FileUtils.mkdir "#{dir}/iclas/#{@filename}"
      svn 'add', "#{dir}/iclas/#{@filename}"

      # update file to be moved
      svn 'mv', "#{dir}/iclas/#{@existing}", 
        "#{dir}/iclas/#@filename/icla#{File.extname(@existing)}"

      # commit changes
      svn 'commit', "#{dir}/iclas", '-m', "move previous ICLA from #{@pubname}"
    end
  end
end

########################################################################
#                          file new document                           #
########################################################################

# determine initial value for the counter
svndir = ASF::SVN['iclas']
count = (Dir["#{svndir}/#@filename/*"].
      map {|name| name[/.*(\d+)\./, 1] || 1}.map(&:to_i).max || 1) + 1

# write attachment (+ signature, if present) to the documents/iclas directory
task "svn commit documents/iclas/icla#{count}#{fileext}" do
  form do
    _input value: @selected, name: 'selected'

    if @signature and not @signature.empty?
      _input value: @signature, name: 'signature'
    end
  end

  complete do |dir|
    # checkout directory
    svn 'checkout', 
      "https://svn.apache.org/repos/private/documents/iclas/#@filename",
      "#{dir}/#@filename"

    # determine numeric suffix for the new ICLA
    count = Dir["#{dir}/#@filename/*"].
      map {|name| name[/.*(\d+)\./, 1] || 1}.map(&:to_i).max + 1

    # create/add file(s)
    files = {@selected => "icla#{count}#{fileext}"}
    files[@signature]  = "icla#{count}pdf.asc" unless @signature.to_s.empty?
    message.write_svn(dir, @filename, files)

    # Show files to be added
    svn 'status', "#{dir}/#@filename"

    # commit changes
    svn 'commit', 
      *files.values.map {|name| "#{dir}/#@filename/#{@name}"},
      '-m', "additional ICLA from #{@pubname}"
  end
end

########################################################################
#                          officers/iclas.txt                          #
########################################################################

# insert line into iclas.txt
task "svn commit foundation/officers/iclas.txt" do
  icla = ASF::ICLA.find_by_id(@id) || ASF::ICLA.find_by_email(@oldemail)
  unless icla and icla.id == @id and icla.email == @oldemail
    raise ArgumentError.new("ICLA not found for #@id:#@oldemail")
  end

  # construct line to be inserted
  @iclaline ||= [
    @id,
    icla.legal_name,
    @pubname.strip,
    @email.strip,
    icla.form
  ].join(':')

  form do
    _input value: @iclaline, name: 'iclaline'
  end

  complete do |dir|
    # checkout empty officers directory
    svn 'checkout', '--depth', 'empty',
      'https://svn.apache.org/repos/private/foundation/officers', 
      "#{dir}/officers"

    # retrieve iclas.txt
    dest = "#{dir}/officers/iclas.txt"
    svn 'update', dest

    # update iclas.txt
    iclas_txt = File.read(dest)
    iclas_txt[/^#{@id}:.*:#{@oldemail}:.*/] = @iclaline
    File.write dest, ASF::ICLA.sort(iclas_txt)

    # show the changes
    svn 'diff', dest

    # commit changes
    svn 'commit', dest, '-m', "ICLA for #{@pubname}"
  end
end

########################################################################
#                      update public name in LDAP                      #
########################################################################

if person.public_name != @pubname and @id != 'notinavail'
  task "change public name in LDAP" do
    form do
      _input value: @pubname, name: 'pubname'
    end

    complete do
      ldap = ASF.init_ldap(true)

      ldap.bind("uid=#{env.user.untaint},ou=people,dc=apache,dc=org",
        env.password.untaint)

      ldap.modify person.dn, [ASF::Base.mod_replace('cn', @pubname.strip)]

      log = ["LDAP modify: #{ldap.err2string(ldap.err)} (#{ldap.err})"]
      if ldap.err == 0
        _transcript log
      else
        _backtrace log
      end

      ldap.unbind
    end
  end
end

########################################################################
#                           email submitter                            #
########################################################################

# send confirmation email
task "email #@email" do
  cc = person.all_mail.map {|email| "#{@pubname.inspect} <#{email}>"}
  cc << 'secretary@apache.org'

  # build mail from template
  mail = message.reply(
    subject: "ICLA for #{@pubname}",
    from: @from,
    to: "#{@pubname.inspect} <#{@email}>",
    cc: cc,
    body: template('icla2.erb')
  )

  # echo email
  form do
    _message mail.to_s
  end

  # deliver mail
  complete do
    mail.deliver!
  end
end

########################################################################
#                     update email address in LDAP                     #
########################################################################

if @id != 'notinavail'
  task "change email address in LDAP" do
    form do
      _input value: @email, name: 'email'
    end

    complete do
      ldap = ASF.init_ldap(true)

      ldap.bind("uid=#{env.user.untaint},ou=people,dc=apache,dc=org",
	env.password.untaint)

      ldap.modify person.dn, [ASF::Base.mod_replace('mail', @email.strip)]

      log = ["LDAP modify: #{ldap.err2string(ldap.err)} (#{ldap.err})"]
      if ldap.err == 0
	_transcript log
      else
	_backtrace log
      end

      ldap.unbind
    end
  end
end
