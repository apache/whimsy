#
# installs subversion
# check outs whimsy tools (a.k.a. asf model)
# install configuration scripts:
#  checkout-svn
#  get-cert
#  ldap-tunnel
#

package 'subversion'
package 'ldap-utils'

directory "/var/tools" do
  user "vagrant"
  group "vagrant"
end

subversion "asf model" do
  repository 'https://svn.apache.org/repos/infra/infrastructure/trunk/projects/whimsy'
  destination "/var/tools"
  user "vagrant"
  group "vagrant"
end

directory '/home/whimsysvn' do
  user "vagrant"
  group "vagrant"
end

directory '/home/whimsysvn/svn' do
  user "vagrant"
  group "vagrant"
end

link '/home/vagrant/svn' do
  to '/home/whimsysvn/svn'
end

directory '/home/vagrant/bin' do
  user "vagrant"
  group "vagrant"
end

file '/home/vagrant/bin/checkout-svn' do
  mode 0755
  content <<-EOF.gsub(/^    /,'')
    #!/bin/bash
    function update {
      if [[ -e $1 ]]; then
        (cd $1; svn update)
      else
        svn checkout $1 --depth=${2:infinity} --username #{node.user}
      fi
    }

    cd $HOME/svn

    update https://svn.apache.org/repos/private/foundation files
  EOF
end

file '/home/vagrant/bin/ldap-tunnel' do
  mode 0755
  content <<-EOF.gsub(/^    /,'')
    #!/bin/bash
    clear
    echo "******************************************************************"
    echo "*                                                                *"
    echo "*                        ASF LDAP Tunnel                         *"
    echo "*                                                                *"
    echo "******************************************************************"
    while [[ 1 ]]; do
      ssh -N -L 6636:minotaur.apache.org:636 #{node.user}@minotaur.apache.org
      sleep 5
    done
  EOF
end

file '/home/vagrant/bin/get-cert' do
  mode 0755
  content <<-EOF.gsub(/^    /,'')
    #!/usr/bin/ruby
    output = `ssh #{node.user}@minotaur.apache.org openssl s_client -connect \\
              minotaur.apache.org:636 -showcerts < /dev/null 2> /dev/null`
    File.open("asf-ldap-client.pem", 'w') do |file|
      file.write output[/^-+BEGIN.*\\n-+END[^\\n]+\\n/m]
    end
    system "sudo chown root:root asf-ldap-client.pem"
    system "sudo mv asf-ldap-client.pem /etc/ldap"
  EOF
end

ruby_block 'update ldap.conf' do
  block do
    ldap_conf = '/etc/ldap/ldap.conf'
    content = File.read(ldap_conf)
    unless content.include? 'ldap-tunnel'
      content.gsub!(/^TLS_CACERT/, '# TLS_CACERT')
      content += "uri ldaps://ldap-tunnel.apache.org:6636\n"
      content += "TLS_CACERT /etc/ldap/asf-ldap-client.pem\n"
      File.open(ldap_conf, 'w') {|file| file.write content}
    end
  end
end

ruby_block 'update hosts' do
  block do
    content = File.read('/etc/hosts')
    unless content.include? 'ldap-tunnel'
      content[/localhost()\b/, 1] = ' ldap-tunnel.apache.org'
      File.open('/etc/hosts', 'w') {|file| file.write content}
    end
  end
end

directory "/var/tools/invoice" do
  user "vagrant"
  group "vagrant"
end
