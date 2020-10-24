FROM ubuntu:20.04

# N.B. passenger --install_dir=/var/lib/gems/m.n.o must agree with ruby version

ENV GEM_HOME="/srv/gems" \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update && \
    apt-get install -y curl software-properties-common apt-utils && \
    curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
    echo "deb http://opensource.wandisco.com/ubuntu bionic svn110" > \
      /etc/apt/sources.list.d/subversion.list && \
    curl -sL http://opensource.wandisco.com/wandisco-debian-new.gpg | \
      apt-key add - &&\
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
      libaprutil1-dev && \
    gem update --system &&\
    gem install bundler passenger --install_dir=/var/lib/gems/2.7.0 && \
    passenger-install-apache2-module --auto && \
    passenger-install-apache2-module --snippet > \
      /etc/apache2/conf-enabled/passenger.conf && \
    pip3 install img2pdf && \
    a2enmod cgi && \
    a2enmod headers && \
    a2enmod rewrite && \
    a2enmod authnz_ldap && \
    a2enmod speling && \
    a2enmod remoteip && \
    a2enmod expires && \
    a2enmod proxy_wstunnel &&\
    echo "ServerName whimsy.local" > /etc/apache2/conf-enabled/servername.conf

RUN echo 'SetEnv GEM_HOME /srv/gems' > /etc/apache2/conf-enabled/gemhome.conf

# Add new items at the end so previous layers can be re-used

# for editing/viewing files only in the container
RUN DEBIAN_FRONTEND='noninteractive' apt-get install -y vim

# for checking ldap settings etc
RUN DEBIAN_FRONTEND='noninteractive' apt-get install -y ldap-utils

# This should be last, as the source is likely to change
# It also takes very little time, so it does not matter if it has to be redone
COPY work/whimsy.conf /etc/apache2/sites-enabled/000-default.conf
COPY work/25-authz_ldap_group_membership.conf /etc/apache2/conf-enabled/25-authz_ldap_group_membership.conf

WORKDIR /srv/whimsy
EXPOSE 80

CMD ["/usr/local/bin/rake", "docker:entrypoint"]
