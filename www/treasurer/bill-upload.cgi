#!/usr/bin/env ruby

require 'whimsy/asf'
require 'wunderbar'
require 'tmpdir'

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

      _label 'Funding source:', for: 'source'
      _textarea name: 'source', id: 'source', cols: 80

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
    # extract remote user's svn credentials
    auth = ['--no-auth-cache', '--non-interactive']
    if $PASSWORD
      auth += ['--username', $USER, '--password', $PASSWORD]
    end

    # destination directory
    bills = 'https://svn.apache.org/repos/private/financials/Bills'

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
      # append funding source to message, if present
      if @source and not @source.empty?
        @message += "\n\nFunding source: #{@source}" 
      end
      
      # perform all operations in a temporary directory
      Dir.mktmpdir do |tmpdir|
        tmpdir.untaint
        Dir.chdir tmpdir do
          _h2 'Commit log'

          # checkout out empty destination directory
          _.system ['svn', 'checkout', '--quiet', '--depth', 'empty', auth,
            File.join(bills, @dest), '.']

          # fetch single file to see if it already exists
          _.system ['svn', 'update', '--quiet', auth, name]

          if File.exist? name
            _pre "File #{name} already exists", class: '_stderr'
          else
            # write file out to disk
            File.write(name, @file.read)
            _.system ['svn', 'add', name]

            # commit
            _.system ['svn', 'commit', auth, '-m', @message, name]
          end
        end
      end
    end
  end
end
