#!/usr/bin/env ruby

require 'wunderbar'

_html do
  _h1 'ASF SVN info'
  _style :system

  _form do
    _input type: 'text', name: 'url', size: 80, placeholder: 'SVN URL'
    _input type: 'submit', value: 'Submit'
  end

  if @url
    # output svn info
    _.system ['svn', 'info', @url,
       (['--username', $USER, '--password', $PASSWORD] if $PASSWORD) ]
  end
end
