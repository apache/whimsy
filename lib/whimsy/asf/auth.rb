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

module ASF

  # parse the <tt>-authorization-template</tt> files contained within
  # <tt>infrastructure-puppet/modules/subversion_server/files/authorization</tt>
  class Authorization
    include Enumerable

    # Return the set of authorizations a given user (availid) has access to.
    def self.find_by_id(value)
      new.select {|auth, ids| ids.include? value}.map(&:first)
    end

    # Select a given <tt>-authorization-template</tt>, valid values are
    # <tt>asf</tt> and <tt>pit</tt>.
    # The optional <tt>auth_path</tt> parameter allows the directory path to be overridden
    # This is intended for testing only
    def initialize(file='asf',auth_path=nil)
      # TODO - should this read the Git repo directly?
      # Probably not: this file is read frequently so would need to be cached anyway
      # The Git clone is updated every 10 minutes which should be sufficiently recent
      if auth_path
        require 'wunderbar'
        Wunderbar.warn "Overriding Git infrastructure-puppet auth path as: #{auth_path}"
        @auth = auth_path
      else
        auth = ASF::Git.find('infrastructure-puppet')
        if auth
          @auth = auth + '/modules/subversion_server/files/authorization'
        else
          # SVN copy is no longer in use - see INFRA-11452
          raise Exception.new("Cannot find Git: infrastructure-puppet")
        end
      end
      @file = file
    end

    # Iteratively return each non_LDAP entry in the authorization file as a pair
    # of values: a name and list of ids.
    def each
      read_auth.scan(/^([-\w]+)=(\w.*)$/).each do |pmc, ids|
        yield pmc, ids.split(',')
      end
    end

    # Return an array of the ou=project entries in the authorization file
    def projects
      arr = []
      #incubator={ldap:cn=incubator,ou=project,ou=groups,dc=apache,dc=org;attr=member}
      read_auth.scan(/^\w[^=]+={ldap:cn=(\w[^,]+),ou=project,ou=groups/).each do |group|
        arr << group[0]
      end
      arr
    end

    # Return the auth path used to find asf-auth and pit-auth
    def path
      @auth
    end

    unless Enumerable.instance_methods.include? :to_h
      # backwards compatibility for Ruby versions <= 2.0
      def to_h
        Hash[self.to_a]
      end
    end

    private

    def read_auth
      File.read("#{@auth}/#{@file}-authorization-template")
    end
  end

  class Person
    # return a list of ASF authorizations that contain this individual
    def auth
      @auths ||= ASF::Authorization.find_by_id(name)
    end
  end

end
