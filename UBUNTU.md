The following instructions were provided by Sam and verified by Patricia to
work with Ubuntu 20.04 Focal Fossa running on top of VirtualBox

# Simplified node.js agenda install:

    sudo apt install -y curl git subversion
    curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
    sudo apt install -y nodejs
    sudo npm install -g yarn
    sudo snap install --classic code

    git clone https://github.com/rubys/whimsy-board-agenda-nodejs.git
    cd whimsy-board-agenda-nodejs
    yarn install
    yarn dev

# Install Ruby-based Whimsy

    sudo apt-get install -y ruby-dev build-essential libgmp3-dev libldap2-dev
    sudo apt-get install -y libsasl2-dev zlib1g-dev imagemagick pdftk ldap-utils
    sudo gem install bundler
    sudo mkdir -p /srv
    sudo chown $(id -u):$(id -g) /srv
    cd /srv
    git clone https://github.com/apache/whimsy.git
    cd whimsy
    bundle install
    sudo ruby -I lib -r whimsy/asf -e "ASF::LDAP.configure"

At this point, you can verify that you can talk to LDAP with a command
like the following:

    ldapsearch -x -LLL uid=pats cn mail

# Add web server:

    cd /srv/whimsy
    rake update svn:update
    sudo apt install -y apache2 libapache2-mod-passenger
    sudo sed -i "/localhost$/s/$/ whimsy.local/" /etc/hosts
    sudo a2enmod authnz_ldap cgid expires headers proxy_http
    sudo a2enmod proxy proxy_wstunnel rewrite speling
    sudo cp /srv/whimsy/config/whimsy.conf /etc/apache2/sites-available

    Note: if you reside outside North America you may wish to use the EU LDAP server
    by changing the references in the whimsy.conf file from
    ldaps://ldap-us.apache.org:636/
    to
    ldaps://ldap-eu.apache.org:636/

    sudo cp /srv/whimsy/config/25-authz_ldap_group_membership.conf /etc/apache2/conf-available
    sudo a2ensite whimsy
    sudo a2enconf 25-authz_ldap_group_membership
    sudo systemctl restart apache2

Visit [http://whimsy.local/](http://whimsy.local/)

