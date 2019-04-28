##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

FROM ubuntu:14.04.3
ENV DEBIAN_FRONTEND noninteractive

ENV RUBY_VERSION 2.2

# generate locales
ENV LANG en_US.UTF-8
RUN locale-gen $LANG

EXPOSE 9292

# system packages
RUN apt-get install -y software-properties-common && \
    apt-add-repository ppa:brightbox/ruby-ng && \
    apt-get update -y && \
    apt-get install -y ruby$RUBY_VERSION  && \
    apt-get install -y ruby$RUBY_VERSION-dev && \
    apt-get install -y build-essential && \
    apt-get install -y libssl-dev && \
    apt-get install -y libldap2-dev && \
    apt-get install -y libsasl2-dev

# board example
RUN gem install whimsy-asf
RUN ruby -r whimsy/asf -e "ASF::LDAP.configure"
ADD . /home/board
WORKDIR /home/board
CMD ["/usr/bin/ruby", "board.rb", "--port=9292"]
