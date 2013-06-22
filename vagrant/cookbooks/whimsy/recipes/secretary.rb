#
# install pdftk
# install escape gem
# install secmail.rb
#

package 'pdftk'

gem_package "escape" do
  gem_binary "/usr/bin/gem"
end

gem_package "mail" do
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

directory "/var/tools/svnrep" do
  user "vagrant"
  group "vagrant"
end

bash "/var/tools/svnrep/foundation" do
  user 'vagrant'
  group 'vagrant'
  code %{
    cd /var/tools/svnrep
    HOME=/home/vagrant svnadmin create foundation
  }
  not_if {File.exist? "/var/tools/svnrep/foundation"}
end

bash "/var/tools/svnrep/documents" do
  user 'vagrant'
  group 'vagrant'
  code %{
    cd /var/tools/svnrep
    HOME=/home/vagrant svnadmin create documents
  }
  not_if {File.exist? "/var/tools/svnrep/documents"}
end

subversion "documents" do
  repository 'file:///var/tools/svnrep/documents'
  destination "/var/tools/secretary/documents"
  user "vagrant"
  group "vagrant"
end

subversion "foundation" do
  repository 'file:///var/tools/svnrep/foundation'
  destination "/var/tools/secretary/foundation"
  user "vagrant"
  group "vagrant"
end

bash "documents received" do
  user 'vagrant'
  group 'vagrant'
  code %{
    cd /var/tools/secretary/documents
    mkdir -p received iclas cclas grants
    svn add *
    svn commit -m 'empty directories'
  }
  not_if {File.exist? "/var/tools/secretary/documents/received"}
end

bash "foundation officers" do
  user 'vagrant'
  group 'vagrant'
  code %{
    cd /var/tools/secretary/foundation
    mkdir -p officers
    if [[ -e /mnt/svn/foundation/officers/ ]]; then
      cd /mnt/svn/foundation/officers/
      cp iclas.txt cclas.txt grants.txt /var/tools/secretary/foundation/officers
      cd -
    fi
    svn add officers
    svn commit -m 'officer files'
  }
  not_if {File.exist? "/var/tools/secretary/foundation/officers"}
end

bash "foundation meetings" do
  user 'vagrant'
  group 'vagrant'
  code %{
    cd /var/tools/secretary/foundation
    mkdir -p Meetings
    if [[ -e /mnt/svn/foundation/Meetings/ ]]; then
      cd /mnt/svn/foundation/Meetings/
      cp -r $(ls -d 2* | tail -1) /var/tools/secretary/foundation/Meetings
      cd -
      find Meetings -name .svn | xargs --no-run-if-empty rm -rf
    fi
    svn add Meetings
    svn commit -m 'meeting files'
  }
  not_if {File.exist? "/var/tools/secretary/foundation/Meetings"}
end

directory "/var/tools/secretary/secmail" do
  user "vagrant"
  group "vagrant"
end

file "/var/tools/secretary/secmail/latest" do
  user "vagrant"
  group "vagrant"
end

subversion "secmail received" do
  repository 'file:///var/tools/svnrep/documents/received'
  destination "/var/tools/secretary/secmail/received"
  user "vagrant"
  group "vagrant"
end

directory "/var/tools/secretary/secmail/tally" do
  user "vagrant"
  group "vagrant"
end

link '/var/tools/secretary/secmail/secmail.py' do
  to '/var/tools/secmail.py'
end

