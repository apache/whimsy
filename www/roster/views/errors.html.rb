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

#
# Error display
#

_html do
  _header do
    _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  end
  _body? do
    _whimsy_body(
      title: '500 Internal Server Error - Apache Whimsy',
      breadcrumbs: {
        roster: '.',
      }
    ) do
      _div.row do
        _div.col_sm_10 do
          _div.panel.panel_danger do
            _div.panel_heading {_h3.panel_title '500 - Internal Server Error'}
            _div.panel_body do
              _p '"Hey, Rocky! Watch me pull a rabbit out of my hat."'
              _p 'Oh, snap!  Something went wrong.  Error details follow:'
              _ul do
                %w( sinatra.error sinatra.route REQUEST_URI ).each do |k|
                  _li "#{k} = #{@errors[k]}"
                end
              end
              _p do
                _ 'ASF Members may also review access protected: '
                _a '/members/log/', href: '/members/log/'
              end 
              _p do
                _ 'Also please check for ASF system errors at: '
                _a 'status.apache.org', href: 'http://status.apache.org/'
              end 
            end
          end
        end
      end
    end
  end
end
