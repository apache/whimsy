#!/usr/bin/env ruby
PAGETITLE = "ASF Treasurer File Upload" # Wvisible:treasurer
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'whimsy/asf'
require 'tmpdir'
require 'escape'

RECORDS = ASF::SVN.svnurl('records')

user = ASF::Person.new($USER)
unless user.treasurer? or user.secretary?
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Treasurer or Secretary\"\r\n\r\n"
  exit
end

_html do
  _style :system
  _style %{
    pre._stdin, pre._stdout, pre._stderr {border: none; padding: 0}
  }

  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'How To Upload records',
      related: {
        'https://treasurer.apache.org/' => 'ASF Treasurer Process Documentation',
      },
      helpblock: -> {
        _p %{
          This form allows the ASF Treasurer and Secretary to upload financial records,
          e.g. 990 annual returns to:
        }
        _a RECORDS, href: RECORDS
      }
    ) do
      # GET: display the data input form for upload
      _whimsy_panel('Upload A New Record', style: 'panel-success') do
        _form.form_horizontal enctype: 'multipart/form-data', method: 'post' do
          _div.form_group do
            _label.control_label.col_sm_2 'Select file to upload', for: 'file'
            _div.col_sm_10 do
              _input.form_control type: 'file', id: 'file', name: 'file', required: true, autofocus: true
            end
          end
          _div.form_group do
            _label.control_label.col_sm_2 'Enter commit message', for: 'message'
            _div.col_sm_10 do
              _textarea.form_control name: 'message', id: 'message', cols: 80, required: true
            end
          end
          _div.form_group do
            _div.col_sm_offset_2.col_sm_10 do
              _input.btn.btn_default type: "submit", value: "Upload"
            end
          end
        end
      end

      # POST: process the upload by checking into svn
      if @file
        _div.well.well_lg do
          # destination directory
          # validate @file and @message form parameters
          if not @file or (@file.respond_to? :empty? and @file.empty?)
            _pre 'File is required', class: '_stderr'
          elsif not @message or @message.empty?
            _pre 'Message is required', class: '_stderr'
          else
            # prefix whimsy tag:
            @message = "Whimsy upload: " + @message
            _p 'Log of your upload/checkin follows:'

            name = @file.original_filename.gsub(/[^-.\w]/, '_').sub(/^\.+/, '_')
            Dir.mktmpdir do |tmpdir|
              ASF::SVN.svn_('checkout', [RECORDS, tmpdir], _,
                  {depth: 'empty', user: $USER, password: $PASSWORD})

              Dir.chdir tmpdir do
                IO.binwrite(name, @file.read)
                ASF::SVN.svn_('add', name, _)

                ASF::SVN.svn_('commit', name, _, {msg: @message, user: $USER, password: $PASSWORD})
              end
            end
          end
        end
      end
    end
  end
end
