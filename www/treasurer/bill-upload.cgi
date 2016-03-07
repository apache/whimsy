#!/usr/bin/env ruby

require 'whimsy/asf'
require 'wunderbar'

user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include?  user or $USER=='ea'
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

_html do
  _title 'ASF Bill upload'

  _style %{
    label {margin-top: 1em; display: block}
    input, textarea {margin-top: 0.5em; margin-left: 4em; display: block}
    input[type=radio] {display: inline}
    input[type=submit] {margin-left: 0}
    fieldset {display: inline-block}
    legend {background-color: #141; color: #DFD; padding: 0.4em}
    legend, fieldset {border-radius: 8px}
  }
  _style :system

  _form enctype: 'multipart/form-data', method: 'post' do
    _fieldset do
      _legend 'ASF Bill upload'

      _label 'Select a file to upload:'
      _input type: 'file', name: 'file', required: true

      _label 'Enter Commit Message:', for: 'message'
      _textarea name: 'message', id: 'message', cols: 80, required: true

      _label 'Select a destination:'
      _div do
        _input 'Bills/received', type: 'radio', name: 'dest', value: 'received',
          checked: true
      end
      _div do
        _input 'Bills/approved', type: 'radio', name: 'dest', value: 'approved'
      end

      _input type: 'submit', value: 'Upload'
    end
  end

  if @file
    # validate @file, @dest form parameters
    name = @file.original_filename.gsub(/[^-.\w]/, '_').sub(/^\.+/, '_').untaint
    @dest.untaint if @dest =~ /^\w+$/

    if @file.respond_to? :empty? and @file.empty?
      _pre 'File is required', class: '_stderr'
    elsif not @message or @message.empty?
      _pre 'Message is required', class: '_stderr'
    elsif not @dest or @dest.empty?
      _pre 'Destination is required', class: '_stderr'
    else
      Dir.chdir File.join(ASF::SVN['private/financials/Bills'], @dest) do
        _h2 'Commit log'

        # cleanup anything left over from previous runs
        `svn cleanup`
        status = `svn status`
        unless status.empty?
          status.scan(/^[?A]\s*\+?\s*(.*)/).flatten.each do |uncommitted|
            _.system ['rm', '-rf', uncommitted]
          end
          if status =~ /^\w/
            _.system ['svn', 'revert', '-R', file]
          end
        end

        _.system 'svn up'

        if File.exist? name
          _pre "File #{name} already exists", class: '_stderr'
        else
          # write file out to disk
          File.open(name, 'wb') {|file| file.write @file.read}
          _.system ['svn', 'add', name]

          # commit
          _.system [
            'svn', 'commit', '-m', @message, name,
            ['--no-auth-cache', '--non-interactive'],
            (['--username', $USER, '--password', $PASSWORD] if $PASSWORD)
          ]
        end
      end
    end
  end
end
