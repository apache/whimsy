#
# install pdftk
# install escape gem
# install secmail.rb
#

package 'pdftk'

gem_package "escape" do
  gem_binary "/usr/bin/gem"
end

directory "/var/tools/secretary" do
  user "vagrant"
  group "vagrant"
end

bash '/var/tools/secretary/secmail.rb' do
  user 'vagrant'
  group 'vagrant'
  code %{
    cp /vagrant/secmail.rb /var/tools/secretary/secmail.rb
  }
  not_if {File.exist? '/var/tools/secretary/secmail.rb'}
end
