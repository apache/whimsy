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
# install apache2
# install and configure suexec
# allow .htaccess overrides
# configure CGI
# enable file extensions to be omitted (MultiViewsMatch)
# set servername
# change owner of web directory to vagrant user and group
# install wunderbar gem
# install jquery
# restart apache2 server
# report on location of dashboard in Chef log and welcome message
#
 
package "apache2"
package "apache2-suexec"

bash 'enable suexec' do
  code 'a2enmod suexec'
  not_if {File.exist? '/etc/apache2/mods-enabled/suexec.load'}
end

bash 'enable headers' do
  code 'a2enmod headers'
  not_if {File.exist? '/etc/apache2/mods-enabled/headers.load'}
end

ruby_block 'update site' do
  block do
    default = '/etc/apache2/sites-available/default'
    original = File.read(default)
    content = original.dup

    unless File.exist? "#{default}.bak"
      File.open("#{default}.bak", 'w') {|file| file.write original}
    end

    unless content.include? 'SuexecUserGroup'
      content.sub! "\n\n", "\n\tSuexecUserGroup vagrant vagrant\n\n"
    end

    unless content.include? 'RequestHeader'
      content.sub! "\n\n", "\n\tRequestHeader set USER \"#{node.user}\"\n\n"
    end

    content.sub!(%r{<Directory /var/www/>.*?\n\s*</Directory>}m) do |var_www|
      var_www.sub! /^\s*AllowOverride\s.*/ do |line|
        line.sub 'None', 'All'
      end

      var_www.sub! /^\s*Options\s.*/ do |line|
        line += ' +ExecCGI' unless line.include? 'ExecCGI'
        line
      end

      unless var_www.include? 'AddHandler cgi-script'
        var_www[%r{^()\s*</Directory>}, 1] = "\t\tAddHandler cgi-script .cgi\n"
      end

      unless var_www.include? 'MultiViewsMatch Any'
        var_www[%r{^()\s*</Directory>}, 1] = "\t\tMultiViewsMatch Any\n"
      end

      var_www
    end

    unless content == original
      File.open(default, 'w') {|file| file.write content}
    end
  end
end

file '/etc/apache2/conf.d/servername' do
  content "ServerName #{`hostname`}"
end

directory '/var/www' do
  user 'vagrant'
  group 'vagrant'
end

subversion "whimsy site" do
  repository 'https://svn.apache.org/repos/infra/infrastructure/trunk/projects/whimsy/www'
  destination "/var/www/whimsy"
  user "vagrant"
  group "vagrant"
end

gem_package "wunderbar" do
  gem_binary "/usr/bin/gem1.9.1"
end

bash '/var/www/jquery-ui.css' do
  user 'vagrant'
  group 'vagrant'
  code %{
    cp /var/tools/www/jquery* /var/www
  }
  not_if {File.exist? '/var/www/jquery.min.js'}
end

link "/var/www/.subversion" do
  to "/home/vagrant/.subversion"
end

directory '/var/www/members' do
  user 'vagrant'
  group 'vagrant'
end

link "/var/www/members/received" do
  to "/var/tools/secretary/documents/received"
end

service "apache2" do 
  action :restart
end

ruby_block 'welcome' do
  ip=%{/sbin/ifconfig eth1|grep inet|head -1|sed 's/\:/ /'|awk '{print \$3}'}

  block do
    profile = '/home/vagrant/.bash_profile'
    unless File.exist?(profile) and File.read(profile).include? ip
      open(profile, 'a') do |file|
        file.puts "\nip=$(#{ip})"
        file.write <<-'EOF'.gsub(/^ {10}/, '')
          if [[ "${TERM:-dumb}" != "dumb" ]]; then
            echo
            echo "Whimsy is available at http://$ip/whimsy"

            PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
          fi
        EOF
      end

      Chef::ShellOut.new("chown vagrant:vagrant #{profile}").run_command
    end

    Chef::Log.info "Whimsy is available at http://" + `#{ip}`.chomp + "/whimsy"
  end
end
