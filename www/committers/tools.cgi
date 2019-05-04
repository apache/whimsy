#!/usr/bin/env ruby
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

PAGETITLE = "Listing Of Whimsy Tools" # Wvisible:tools

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require '../../tools/wwwdocs.rb'

NONCGIS = {
  '/board/agenda/' => 
    [ 'Board Agenda Tool', 
      ['board', 'meeting'],
    'text-primary'],
  '/roster/' => 
    [ 'ASF Roster Tool', 
      ['orgchart'],
    'text-muted']
}

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE, 
      related: {
        "https://projects.apache.org/" => "Apache Project Listing",
        "https://reference.apache.org/" => "Infra Reference Pages",
        "https://github.com/apache/whimsy/blob/master/www/committers/tools.cgi" => "See This Code",
        "mailto:dev@whimsical.apache.org?subject=[FEEDBACK] committers/tools idea" => "Email Feedback To dev@whimsical"
      },
      helpblock: -> {
        _p.pull_right do
          _ 'This page shows a '
          _em 'partial'
          _ ' listing of tools that Whimsy provides.'
        end
        _ul do
          _li do
            _span.glyphicon :aria_hidden, class: "#{AUTHPUBLIC}"
            _ 'Publicly available'
          end
          AUTHMAP.each do |realm, style|
            _li do
              _span.glyphicon.glyphicon_lock :aria_hidden, class: "#{style}", aria_label: "#{realm}"
              _ "#{realm}"
            end
          end
        end
      }
    ) do
      scan = get_annotated_scan("../#{SCANDIR}")
      scan.merge!(NONCGIS)
      scan_by = scan.group_by{ |k, v| v[1][0] }
      _ul.list_inline do
        scan_by.each do |cat, l|
          _li do
            _a "#{cat.capitalize}", href: "##{cat}"
          end
        end
      end
      scan_by.each do | category, links |
        _ul.list_group do
          _li.list_group_item.active do
            _span category.capitalize, id: category
          end
          links.each do |l, desc|
            _li.list_group_item do
              if 2 == desc.length
                _span.glyphicon :aria_hidden, class: "#{AUTHPUBLIC}"
              else
                _span class: desc[2], aria_label: "#{AUTHMAP.key(desc[2])}" do
                  _span.glyphicon.glyphicon_lock :aria_hidden
                end
              end
              _a "#{desc[0]}", href: l
              _ ' - '
              _code! do
                _a "#{l}", href: l
              end
            end
          end
        end
      end
    end
  end
end
