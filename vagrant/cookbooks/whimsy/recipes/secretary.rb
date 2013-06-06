#
# install Ruby 1.9.3, subversion and nokogiri
# checkout whimsy to a svn directory
#

package 'ruby1.9.3'
package 'subversion'
package 'pdftk'

directory "/var/tools" do
  user "vagrant"
  group "vagrant"
end

directory "/var/tools/secretary" do
  user "vagrant"
  group "vagrant"
end

gem_package "escape" do
  gem_binary "/usr/bin/gem"
end

bash '/var/tools/secretary/secmail.rb' do
  user 'vagrant'
  group 'vagrant'
  code %{
    cp /vagrant/secmail.rb /var/tools/secretary/secmail.rb
  }
  not_if {File.exist? '/var/tools/secretary/secmail.rb'}
end

