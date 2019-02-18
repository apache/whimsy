#!/usr/bin/env ruby
PAGETITLE = "Subversion Info Helper" # Wvisible:tools svn
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'

_html do
  _body? do
    _style :system
    _whimsy_body(
      title: PAGETITLE,
      related: {
        'https://www.apache.org/dev/#version-control' => "How To Use Apache's SVN and Git",
        'https://svn.apache.org/viewvc/' => 'View Public SVN Repositories',
        'https://github.com/apache/' => 'View Public Git Repositories'
      },
      helpblock: -> {
        _ 'Enter the URL to a file in an Apache Subversion repository to see the results of the '
        _code 'svn info'
        _ "command on that file.  This is useful if you don't have a subversion client locally."
      }
    ) do
            
      _form do
        _div.form_group do
          _label.control_label for: 'url' do
            _ 'Enter a svn.apache.org/repos URL'
          end
          _input.form_control type: 'text', name: 'url', size: 120, placeholder: 'https://svn.apache.org/repos/asf/'
        end
        _div.form_group do
          _input.btn.btn_primary type: 'submit', value: 'Submit'
        end
      end
      
      if @url
        # output svn info
        _div.well.well_lg do
          _.system ['svn', 'info', @url,
            ['--non-interactive', '--no-auth-cache'], # not needed in output
            (['--username', $USER, '--password', $PASSWORD] if $PASSWORD) ] # must not be in output
        end
      end
    end
  end
end
