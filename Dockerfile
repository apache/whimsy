FROM ubuntu:14.04.2

RUN  mkdir -p /srv/var

ENV RUBY_VERSION 2.2
ENV PHANTOMJS_VERSION 2.0.0
ENV IOJS_VERSION 1.5.0

EXPOSE 9292

# system packages
RUN apt-get install -y software-properties-common && \
    apt-add-repository ppa:brightbox/ruby-ng && \
    apt-get update -y && \
    apt-get install -y ruby$RUBY_VERSION  && \
    apt-get install -y ruby$RUBY_VERSION-dev && \
    apt-get install -y wget && \
    apt-get install -y build-essential && \
    apt-get install -y libssl-dev && \
    apt-get install -y libldap2-dev && \
    apt-get install -y libsasl2-dev && \
    apt-get install -y libxml2-dev && \
    apt-get install -y subversion && \
    apt-get install -y lsof

# io.js
WORKDIR /home
RUN wget https://iojs.org/dist/v$IOJS_VERSION/iojs-v$IOJS_VERSION-linux-x64.tar.xz  && \
    tar -vxf iojs-v$IOJS_VERSION-linux-x64.tar.xz && \
    rm -f iojs-v$IOJS_VERSION-linux-x64.tar.xz && \
    mv iojs-v$IOJS_VERSION-linux-x64/ /srv/var/iojs && \
    ln -s /srv/var/iojs/bin/iojs /usr/bin/iojs && \
    ln -s /srv/var/iojs/bin/node /usr/bin/node && \
    ln -s /srv/var/iojs/bin/npm /usr/bin/npm

# phantom.js - 2.0.0
# https://github.com/ariya/phantomjs/issues/12948#issuecomment-78181293
RUN apt-get install -y libfreetype6 && \
    apt-get install -y libjpeg8 && \
    apt-get install -y libfontconfig && \
    wget http://security.ubuntu.com/ubuntu/pool/main/i/icu/libicu48_4.8.1.1-3ubuntu0.5_amd64.deb && \
    dpkg -i libicu48_4.8.1.1-3ubuntu0.5_amd64.deb && \
    rm -f libicu48_4.8.1.1-3ubuntu0.5_amd64.deb && \
    wget https://s3.amazonaws.com/travis-phantomjs/phantomjs-$PHANTOMJS_VERSION-ubuntu-12.04.tar.bz2 && \
    tar -vxjf phantomjs-$PHANTOMJS_VERSION-ubuntu-12.04.tar.bz2 phantomjs && \
    rm -f phantomjs-$PHANTOMJS_VERSION-ubuntu-12.04.tar.bz2 && \
    mv phantomjs /srv/var/phantomjs && \
    ln -s /srv/var/phantomjs /usr/bin/phantomjs

# Clean Up
Run apt-get automermove -y && \
   apt-get clean all && \
   rm -rf /var/cache/apt/* && \
   rm -rf /var/lib/apt/lists/* && \
   rm -Rf /tmp/* && \
   rm -rf /var/tmp/*

# Whimsy Agenda
RUN apt-get install zlib1g-dev
RUN gem install bundler
ADD Gemfile /home/agenda/ 
WORKDIR /home/agenda
RUN bundle install
ADD package.json /home/agenda/
RUN npm install
ADD . /home/agenda
RUN rake spec
CMD ["/usr/bin/rake", "server:test"]
