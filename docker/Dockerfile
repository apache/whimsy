FROM ubuntu:18.04
ENV GEM_HOME="/srv/gems" \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8
RUN apt-get update && \
    apt-get install -y curl && \
    curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
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
    gem install bundler passenger --install_dir=/var/lib/gems/2.5.0 && \
    passenger-install-apache2-module --auto && \
    passenger-install-apache2-module --snippet > /etc/apache2/conf-enabled/passenger.conf && \
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
COPY work/whimsy.conf /etc/apache2/sites-enabled/000-default.conf
RUN echo 'SetEnv GEM_HOME /srv/gems' > /etc/apache2/conf-enabled/gemhome.conf
WORKDIR /srv/whimsy
EXPOSE 80

CMD ["/usr/local/bin/rake", "docker:entrypoint"]
