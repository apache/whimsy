#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'wunderbar'
require 'whimsy/asf'

_html do
  _body? do
    _style :system
    _whimsy_header 'ASF SVN info'
    _whimsy_content do
      _p.lead 'SVN Info takes a URL and reports info on that file in the repository.'
      _form do
        _div.form_group do
          _label.control_label for: 'url' do
            _ 'Enter a svn.apache.org/repos URL'
          end
          _input.form_control type: 'text', name: 'url', size: 120, placeholder: 'SVN URL'
        end
        _div.form_group do
          _input.btn.btn_primary type: 'submit', value: 'Submit'
        end
      end
      
      if @url
        # output svn info
        _.system ['svn', 'info', @url,
          (['--username', $USER, '--password', $PASSWORD] if $PASSWORD) ]
        end
      end
    end
  end
