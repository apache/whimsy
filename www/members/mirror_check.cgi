#!/usr/bin/env ruby
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

