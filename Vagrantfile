# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "ubuntu/trusty64"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  config.vm.network "forwarded_port", guest: 9292, host: 9292

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Define a Vagrant Push strategy for pushing to Atlas. Other push strategies
  # such as FTP and Heroku are also available. See the documentation at
  # https://docs.vagrantup.com/v2/push/atlas.html for more information.
  # config.push.define "atlas" do |push|
  #   push.app = "YOUR_ATLAS_USERNAME/YOUR_APPLICATION_NAME"
  # end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  config.vm.provision "shell", inline: <<-SHELL
     mkdir -p /usr/local
     
     RUBY_VERSION 2.2
     PHANTOMJS_VERSION=2.0.0
     IOJS_VERSION=1.5.0

     # system packages
     apt-get install -y software-properties-common
     apt-add-repository ppa:brightbox/ruby-ng
     apt-get update -y
     apt-get install -y ruby$RUBY_VERSION  
     apt-get install -y ruby$RUBY_VERSION-dev 
     apt-get install -y wget 
     apt-get install -y build-essential 
     apt-get install -y libssl-dev 
     apt-get install -y libldap2-dev 
     apt-get install -y libsasl2-dev 
     apt-get install -y libxml2-dev 
     apt-get install -y subversion 
     apt-get install -y lsof
     apt-get install zlib1g-dev

     # io.js
     cd /usr/local
     wget https://iojs.org/dist/v$IOJS_VERSION/iojs-v$IOJS_VERSION-linux-x64.tar.xz  
     tar -vxf iojs-v$IOJS_VERSION-linux-x64.tar.xz 
     rm -f iojs-v$IOJS_VERSION-linux-x64.tar.xz 
     ln -s /usr/local/iojs/bin/iojs /usr/bin/iojs 
     ln -s /usr/local/iojs/bin/node /usr/bin/node 
     ln -s /usr/local/iojs/bin/npm /usr/bin/npm

     # phantom.js - 2.0.0
     # https://github.com/ariya/phantomjs/issues/12948#issuecomment-78181293
     apt-get install -y libfreetype6 
     apt-get install -y libjpeg8 
     apt-get install -y libfontconfig 
     wget http://security.ubuntu.com/ubuntu/pool/main/i/icu/libicu48_4.8.1.1-3ubuntu0.5_amd64.deb 
     dpkg -i libicu48_4.8.1.1-3ubuntu0.5_amd64.deb 
     rm -f libicu48_4.8.1.1-3ubuntu0.5_amd64.deb 
     wget https://s3.amazonaws.com/travis-phantomjs/phantomjs-$PHANTOMJS_VERSION-ubuntu-12.04.tar.bz2 
     tar -vxjf phantomjs-$PHANTOMJS_VERSION-ubuntu-12.04.tar.bz2 phantomjs 
     rm -f phantomjs-$PHANTOMJS_VERSION-ubuntu-12.04.tar.bz2 
     ln -s /usr/local/phantomjs /usr/bin/phantomjs

     # Whimsy Agenda
     cd /vagrant
     gem install bundler
     bundle install
     package.json /home/agenda/
     npm install
     rake spec
  SHELL
end
