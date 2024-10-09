FROM ubuntu:24.04

# N.B. passenger --install_dir=/var/lib/gems/m.n.o must agree with ruby version

ENV GEM_HOME="/srv/gems" \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update && \
    apt-get install -y curl software-properties-common apt-utils && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
      gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
      echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" > \
      /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    DEBIAN_FRONTEND='noninteractive' apt-get install -y \
      apache2 \
      subversion \
      git \
      build-essential \
      libgmp3-dev \
      libldap2-dev \
      libsasl2-dev \
      python3-pip \
      ruby-dev \
      zlib1g-dev \
      imagemagick \
      img2pdf \
      nodejs \
      procmail \
      poppler-utils \
      texlive-extra-utils \
      gnupg2 \
      libcurl4-openssl-dev \
      libssl-dev \
      apache2-dev \
      libapr1-dev \
      libaprutil1-dev

      # Note: gem system is maintained by Ubuntu now
RUN gem install bundler --install_dir=/var/lib/gems/3.2.0
RUN gem install passenger --install_dir=/var/lib/gems/3.2.0 && \
    passenger-install-apache2-module --auto && \
    passenger-install-apache2-module --snippet >/etc/apache2/conf-enabled/passenger.conf 

# Note: pips are generally maintained by Ubuntu now
RUN DEBIAN_FRONTEND='noninteractive' apt-get install -y python3-img2pdf

RUN \
    a2enmod cgi && \
    a2enmod headers && \
    a2enmod rewrite && \
    a2enmod authnz_ldap && \
    a2enmod speling && \
    a2enmod expires && \
    a2enmod proxy_wstunnel &&\
    echo "ServerName whimsy.local" > /etc/apache2/conf-enabled/servername.conf

RUN echo 'SetEnv GEM_HOME /srv/gems' > /etc/apache2/conf-enabled/gemhome.conf

# Add new items at the end so previous layers can be re-used

# for editing/viewing files only in the container
RUN DEBIAN_FRONTEND='noninteractive' apt-get install -y vim

# for checking ldap settings etc
RUN DEBIAN_FRONTEND='noninteractive' apt-get install -y ldap-utils

# Install puppeteer
COPY docker-config/puppeteer-install.sh /tmp/puppeteer-install.sh
RUN bash /tmp/puppeteer-install.sh && rm /tmp/puppeteer-install.sh

# Fix for psych 5.0.0
RUN DEBIAN_FRONTEND='noninteractive' apt-get install -y libyaml-dev

#  For testing agenda, you may need the following:
# Find the chrome version:
# google-chrome --version
# Install chromedriver:
# e.g. curl -o chromedriver.zip https://chromedriver.storage.googleapis.com/99.0.4844.51/chromedriver_linux64.zip
# unzip it:
# unzip chromedriver.zip
# mv chromedriver /usr/bin/chromedriver
# chown root:root /usr/bin/chromedriver
# chmod +x /usr/bin/chromedriver

# Allow www-data user to use Git repo owned by root
COPY docker-config/gitconfig-www /var/www/.gitconfig

COPY docker-config/maintenance_banner.lua /etc/apache2
COPY docker-config/logformat.conf /etc/apache2/conf-enabled/logformat.conf

# disable security check and telemetry
# Must use the same user and group as apache
RUN sed -i -e '$i  PassengerDisableSecurityUpdateCheck on' /etc/apache2/conf-enabled/passenger.conf && \
    sed -i -e '$i  PassengerDisableAnonymousTelemetry on' /etc/apache2/conf-enabled/passenger.conf && \
    sed -i -e '$i  PassengerUser www-data' /etc/apache2/conf-enabled/passenger.conf && \
    sed -i -e '$i  PassengerGroup www-data' /etc/apache2/conf-enabled/passenger.conf

# For running SVN in the container
RUN apt-get install libapache2-mod-svn

# for maintenance banner
RUN DEBIAN_FRONTEND='noninteractive' apt-get install -y \
  lua5.2 && \
  a2enmod lua

# For /usr/bin/host (used in acreq.erb)
RUN DEBIAN_FRONTEND='noninteractive' apt-get install -y host

WORKDIR /srv/whimsy
RUN git config --global --add safe.directory /srv/whimsy

# Use the same port internally and externally so SVN URLs are the same
RUN sed -i -e 's/Listen 80/Listen 1999/' /etc/apache2/ports.conf
EXPOSE 1999

# Note: the httpd and LDAP config is now done in the container as part of startup
# This is to avoid storing any credentials in the image
CMD ["/usr/local/bin/rake", "docker:entrypoint"]
