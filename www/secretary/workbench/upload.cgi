#!/usr/bin/env ruby
require 'wunderbar'
require 'mail'

_html do
  _head do
    _title 'Upload an email'
    _style %{
      pre {font-weight: bold; margin: 0} 
      pre._stdin  {color: #C000C0; margin-top: 1em} 
      pre._stdout {color: #000} 
      pre._stderr {color: #F00} 
    }
  end

  _body do
    _h2 'Upload an email'
    _form method: 'post', enctype: 'multipart/form-data' do
      _input type: 'file', name: 'file'
      _input type: 'submit', value: 'send'
    end

    if @file
      Dir.chdir('/var/tools/secretary/secmail') do
        # write email to mailbox
        upload = @file.read
        mail = Mail.new {from upload[/^From: (.*?)[\r\n]/i, 1]}
        time = Time.now.asctime
        File.open('mailbox', 'w') do |file|
          file.write "From #{mail.from.first}  #{time}\r\n"
          file.write upload
        end

        # allow emails previously processed to be processed again
        Dir['tally/*'].each {|file| File.unlink file.untaint}

        _.system 'python secmail.py' 
      end

      Dir.chdir('/var/tools/secretary/documents') do
        # update received
        _.system 'svn update received' 
      end

      _script 'parent.frames[0].location.reload()'
    end
  end
end
