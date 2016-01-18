FROM ubuntu:14.04.3
ENV DEBIAN_FRONTEND noninteractive

RUN mkdir -p /srv/var

ENV RUBY_VERSION 2.3
ENV PHANTOMJS_VERSION 2.0.0
ENV NODEJS_VERSION 5

# generate locales
ENV LANG en_US.UTF-8
RUN locale-gen $LANG

EXPOSE 9292

# system packages
RUN apt-get install -y software-properties-common && \
    apt-add-repository ppa:brightbox/ruby-ng && \
    apt-get install -y curl &&\
    (curl -sL https://deb.nodesource.com/setup_${NODEJS_VERSION}.x | \
       sudo -E bash -) && \
    apt-get update -y && \
    apt-get install -y nodejs &&\
    apt-get install -y ruby$RUBY_VERSION  && \
    apt-get install -y ruby$RUBY_VERSION-dev && \
    apt-get install -y wget && \
    apt-get install -y build-essential && \
    apt-get install -y libssl-dev && \
    apt-get install -y libldap2-dev && \
    apt-get install -y libsasl2-dev && \
    apt-get install -y libxml2-dev && \
    apt-get install -y subversion && \
    apt-get install -y lsof && \
    apt-get install -y zlib1g-dev

# phantom.js - 2.0.0
# https://github.com/ariya/phantomjs/issues/12948#issuecomment-78181293
RUN apt-get install -y libfreetype6 && \
    apt-get install -y libjpeg8 && \
    apt-get install -y libfontconfig && \
    wget http://security.ubuntu.com/ubuntu/pool/main/i/icu/libicu48_4.8.1.1-3ubuntu0.6_amd64.deb && \
    dpkg -i libicu48_4.8.1.1-3ubuntu0.6_amd64.deb && \
    rm -f libicu48_4.8.1.1-3ubuntu0.6_amd64.deb && \
    wget https://s3.amazonaws.com/travis-phantomjs/phantomjs-$PHANTOMJS_VERSION-ubuntu-12.04.tar.bz2 && \
    tar -vxjf phantomjs-$PHANTOMJS_VERSION-ubuntu-12.04.tar.bz2 phantomjs && \
    rm -f phantomjs-$PHANTOMJS_VERSION-ubuntu-12.04.tar.bz2 && \
    ln -s /srv/var/phantomjs /usr/bin/phantomjs

# Clean Up
RUN apt-get autoremove -y && \
   apt-get clean all && \
   rm -rf /var/cache/apt/* && \
   rm -rf /var/lib/apt/lists/* && \
   rm -Rf /tmp/* && \
   rm -rf /var/tmp/*

# Whimsy Agenda
RUN gem install bundler
ADD Gemfile /home/agenda/ 
WORKDIR /home/agenda
RUN bundle install
RUN ruby -r whimsy/asf -e "ASF::LDAP.configure"
ADD package.json /home/agenda/
RUN npm install
ADD . /home/agenda
RUN rake clobber
RUN rake spec
CMD ["/usr/bin/rake", "server:test"]
