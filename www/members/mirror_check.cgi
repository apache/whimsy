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

PAGETITLE = "ASF Distribution Mirror Checker" # Wvisible:infra mirror
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require "../../tools/mirror_check.rb"

_html do
  _body? do
    _whimsy_body(
    title: PAGETITLE,
    related: {
      'http://www.apache.org/info/how-to-mirror.html' => 'How To Setup An ASF Mirror',
      'https://www.apache.org/dev/mirrors' => 'Overview of ASF Mirror Systems',
    },
    helpblock: -> {
      _p do
        _ 'This page can be used to check that a proposed Apache software distribution mirror has been set up correctly.'
      end
      _p do
        _ 'Please see the'
        _a 'Apache how-to mirror page', href: 'http://www.apache.org/info/how-to-mirror.html'
        _ 'for the full details on setting up an ASF mirror.'
      end
      _p 'Note that not all mirrors have to carry the OpenOffice distributables'
    }
    ) do
      _whimsy_panel('Check A Mirror Site', style: 'panel-success') do
        _form.form_horizontal method: 'post' do
          _div.form_group do
            _label.control_label.col_sm_2 'Mirror URL', for: 'url'
            _div.col_sm_10 do
              _input.form_control.name name: 'url', required: true,
                value: ENV['QUERY_STRING'],
                placeholder: 'mirror URL',
                size: 50
            end
          end
          _div.form_group do
            _div.col_sm_offset_2.col_sm_10 do
              _input.btn.btn_default type: 'submit', value: 'Check Mirror'
            end
          end
        end
      end
      _div.well.well_lg do
        if _.post?
          doPost(@url)
        end
      end
    end
  end
end

