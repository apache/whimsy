FROM ubuntu:14.04.2

RUN  mkdir -p /srv/var

ENV PHANTOMJS_VERSION 1.9.8
ENV IOJS_VERSION 1.5.0

RUN apt-get update -y
RUN apt-get install -y ruby-full
RUN apt-get install -y wget
RUN apt-get install -y subversion
RUN apt-get install -y xz-utils

# io.js
WORKDIR /home
RUN wget https://iojs.org/dist/v$IOJS_VERSION/iojs-v$IOJS_VERSION-linux-x64.tar.xz
RUN tar -vxf iojs-v$IOJS_VERSION-linux-x64.tar.xz
RUN rm -f iojs-v$IOJS_VERSION-linux-x64.tar.xz
RUN mv iojs-v$IOJS_VERSION-linux-x64/ /srv/var/iojs
RUN ln -s /srv/var/iojs/bin/iojs /usr/bin/iojs
RUN ln -s /srv/var/iojs/bin/node /usr/bin/node
RUN ln -s /srv/var/iojs/bin/npm /usr/bin/npm

# phantom.js
RUN apt-get install -y git libfreetype6
RUN wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2
RUN tar -vxjf phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2
RUN rm -f phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2
RUN mv phantomjs-$PHANTOMJS_VERSION-linux-x86_64/ /srv/var/phantomjs
RUN ln -s /srv/var/phantomjs/bin/phantomjs /usr/bin/phantomjs

# Whimsy Agenda
RUN apt-get install zlib1g-dev
RUN gem install bundler
RUN svn checkout https://svn.apache.org/repos/infra/infrastructure/trunk/projects/whimsy/www/test/board/agenda /home/agenda
WORKDIR /home/agenda
RUN npm install
RUN bundle install
RUN rake spec
RUN rake server:test