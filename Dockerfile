FROM ubuntu:14.04.2

RUN  mkdir -p /srv/var

ENV PHANTOMJS_VERSION 2.0.0
ENV IOJS_VERSION 1.5.0

RUN apt-get update -y
RUN apt-get install -y ruby-full
RUN apt-get install -y wget
RUN apt-get install -y subversion
RUN apt-get install -y xz-utils
RUN apt-get install -y build-essential
RUN apt-get install -y libssl-dev
RUN apt-get install -y libldap2-dev
RUN apt-get install -y libsasl2-dev

# io.js
WORKDIR /home
RUN wget https://iojs.org/dist/v$IOJS_VERSION/iojs-v$IOJS_VERSION-linux-x64.tar.xz
RUN tar -vxf iojs-v$IOJS_VERSION-linux-x64.tar.xz
RUN rm -f iojs-v$IOJS_VERSION-linux-x64.tar.xz
RUN mv iojs-v$IOJS_VERSION-linux-x64/ /srv/var/iojs
RUN ln -s /srv/var/iojs/bin/iojs /usr/bin/iojs
RUN ln -s /srv/var/iojs/bin/node /usr/bin/node
RUN ln -s /srv/var/iojs/bin/npm /usr/bin/npm

# phantom.js - 2.0.0
# https://github.com/ariya/phantomjs/issues/12948#issuecomment-78181293
RUN apt-get install -y libfreetype6
RUN apt-get install -y libjpeg8
RUN wget http://security.ubuntu.com/ubuntu/pool/main/i/icu/libicu48_4.8.1.1-3ubuntu0.5_amd64.deb
RUN dpkg -i libicu48_4.8.1.1-3ubuntu0.5_amd64.deb
RUN rm -f libicu48_4.8.1.1-3ubuntu0.5_amd64.deb
RUN wget https://s3.amazonaws.com/travis-phantomjs/phantomjs-$PHANTOMJS_VERSION-ubuntu-12.04.tar.bz2
RUN tar -vxjf phantomjs-$PHANTOMJS_VERSION-ubuntu-12.04.tar.bz2 phantomjs
RUN rm -f phantomjs-$PHANTOMJS_VERSION-ubuntu-12.04.tar.bz2
RUN mv phantomjs /srv/var/phantomjs
RUN ln -s /srv/var/phantomjs /usr/bin/phantomjs

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
CMD ['rake', 'server:test']
