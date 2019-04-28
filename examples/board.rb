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

# To run with output going to STDOUT:
#
#   ruby examples/board.rb
#
# To run as a server:
#
#   ruby examples/board.rb --port=8080
#
# To install on a server that supports CGI:
#
#   ruby examples/board.rb --install=/Users/rubys/Sites/

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'

_html do
  _h1_ 'List of ASF board members'

  _table do
    _tr do
      _th 'id'
      _th 'name'
      _th 'mail'
    end

    ASF::Service.find('board').members.each do |person|
      _tr_ do
        _td person.id
        _td person.public_name
        _td person.mail.first
      end
    end
  end
end
