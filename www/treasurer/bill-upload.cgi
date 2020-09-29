#!/usr/bin/env ruby
PAGETITLE = "Apache Treasurer Bill Upload" # Wvisible:treasurer
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'whimsy/asf'
require 'tmpdir'
require 'escape'


user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
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
      subtitle: 'How To Upload Bills',
      related: {
        'https://treasurer.apache.org/' => 'ASF Treasurer Process Documentation',
      },
      helpblock: -> {
        _p %{
          This form allows ASF Members and Officers to upload invoices or
          bills to be submitted for payment.
        }
        _p %{
          Remember: only allowed approvers for a specific bill should
          put or move bills into the /approved directory.
        }
      }
    ) do
      # GET: display the data input form for upload
      _whimsy_panel('Upload A New Bill', style: 'panel-success') do
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
            _label.control_label.col_sm_2 'Funding source (optional)', for: 'source'
            _div.col_sm_10 do
              _textarea.form_control name: 'source', id: 'source', cols: 80
            end
          end
          _div.form_group do
            _label.control_label.col_sm_2 'Select destination', for: "dest"
            _div.col_sm_10 do
              _select.form_control name: 'dest', id: 'dest' do
                _option 'Bills/received', type: 'radio', name: 'dest', value: 'received', checked: true
                _option 'Bills/approved', type: 'radio', name: 'dest', value: 'approved'
              end
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
          bills = ASF::SVN.svnurl('Bills')

          # validate @file, @dest form parameters
          name = @file.original_filename.gsub(/[^-.\w]/, '_').sub(/^\.+/, '_')
          raise ArgumentError, "Unexpected directory name" unless @dest =~ /^\w+$/

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
            _p 'Log of your upload/checkin follows:'

            Dir.mktmpdir do |tmpdir|
              ASF::SVN.svn_('checkout', [File.join(bills, @dest), tmpdir], _,
                  {depth: 'empty', user: $USER, password: $PASSWORD})

              Dir.chdir tmpdir do
                IO.binwrite(name, @file.read)
                ASF::SVN.svn_('add', name, _)

                ASF::SVN.svn_('commit', name, _, {user: $USER, password: $PASSWORD})
              end
            end
          end
        end
      end
    end
  end
end
