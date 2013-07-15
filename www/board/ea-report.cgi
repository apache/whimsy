#!/usr/local/rvm/wrappers/ruby-2.0.0-p247/ruby
# above uses Ruby 2.0 as Ruby 1.9 segfaults when uploading a docx file

require 'wunderbar'
require '/var/tools/asf'

_html do
  _head do
    _title 'Upload EA report'
    _style %{
      pre._stderr {color: #F00; font-weight: bold} 
      button {display: block}
    }
    _script src: '/jquery.min.js'
    _script src: 'reflow.js'
  end

  _body do
    text = ''

    if @file
      semaphore = Mutex.new
      Open3.popen3('docx2txt') do |pin, pout, perr|
        [
          Thread.new { pin.binmode; pin.write @file.read; pin.close },
          Thread.new { text = pout.read },
          Thread.new { _pre perr.read, class: '_stderr' unless perr.eof? }
        ].each {|thread| thread.join}
      end

      unless text.empty?
        text.gsub! /^/, "\n "
        text.gsub! /^ (\w)/, '\1'
        text.gsub! /\s+\Z/, "\n"
        _form do
          _textarea text, name: 'report', cols: 80, rows: 40
          _button 'commit'
        end
        _script 'reflow($("textarea"));'
      end
    end

    if @report
      Dir.chdir ASF::SVN['private/foundation/board'] do
        _.system 'svn up'

        agenda = Dir["board_agenda_*.txt"].sort.last.untaint
        File.open(agenda, 'r+') do |file|
          contents = file.read
          pattern = /^Attachment \d: [^\n]Executive Assistant.*?\n\n(.*?)\n\n-/m
          contents[pattern, 1] = @report
          file.seek(0)
          file.write(contents)
          file.close()
        end

        _.system [
          'svn', 'commit', '-m', 'Executive Assistant report',  agenda,
          ['--no-auth-cache', '--non-interactive'],
          (['--username', $USER, '--password', $PASSWORD] if $PASSWORD)
        ]
      end

    elsif text.empty?
      _h2 'Upload report in docx format'
      _form method: 'post', enctype: 'multipart/form-data' do
        _input type: 'file', name: 'file'
        _input type: 'submit', value: 'send'
      end
    end
  end
end
