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
# common banner
#

class Wunderbar::HtmlMarkup
  def _banner(args)
    _div.header.container_fluid do
      _div.row do
        _div.col_sm_4.hidden_xs do
          _a href: 'https://www.apache.org/' do
            _img title: 'ASF Logo', alt: 'ASF Logo', width: 250, height: 101,
              style: "margin-left: 10px; margin-top: 10px;",
              src: 'https://www.apache.org/foundation/press/kit/asf_logo_small.png'
          end
        end
        _div.col_sm_3.col_xs_3 do
          _a href: '/' do
            _img title: 'Whimsy logo', alt: 'Whimsy hat', src: '/whimsy.svg', width: 145, height: 101 
          end
        end
        _div.col_sm_5.col_xs_9.align_bottom do 
          _ul class: 'nav nav-tabs' do
            _li role: 'presentation' do
              _a 'Code', href: 'https://github.com/apache/whimsy/'
            end
            _li role: 'presentation' do
              _a 'Questions', href: 'https://lists.apache.org/list.html?dev@whimsical.apache.org'
            end
            _li role: 'presentation' do
              _a 'About', href: '/technology'
            end
            _li role: 'presentation' do
              _span.badge id: 'script-ok'
            end
          end
        end
      end
      # breadcrumbs
      if args[:breadcrumbs]
        _div.breadcrumbs do
          _a href: 'http://www.apache.org' do
            _span.glyphicon.glyphicon_home
          end
          
          _a 'whimsy', href: '/'
          args[:breadcrumbs].each do |name, link|
            _span "\u00BB"
            _a name.to_s, href: link
          end
        end
      end
    end
  end
end
