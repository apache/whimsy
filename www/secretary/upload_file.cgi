#!/usr/bin/env ruby
PAGETITLE = "ASF Upload file service" # Wvisible:members upload
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'whimsy/asf/rack' # Ensures server auth is passed thru; provides ASF::Auth module

_html do
  _body? do
    _whimsy_body(
    title: PAGETITLE,
    helpblock: -> {
      _p do
        _ 'Upload a new file to SVN using your credentials'
        _br
        _ 'The file will have the same name in SVN, so rename it locally first if necessary'
      end
    }
    ) do
      _whimsy_panel('Upload a new file to SVN', style: 'panel-success') do
        _form.form_horizontal method: 'post', enctype: "multipart/form-data" do
          _div.form_group do
            _label.control_label.col_sm_2 'SVN path', for: 'url'
            _div.col_sm_10 do
              _input.form_control.name name: 'url', required: true, placeholder: 'SVN URL path to parent directory'
            end
          end
          _div.form_group do
            _label.control_label.col_sm_2 'Source file', for: 'source'
            _div.col_sm_10 do
              _input.form_control.name name: 'source', required: true, type: 'file'
            end
          end
          _div.form_group do
            _label.control_label.col_sm_2 'Message', for: 'msg'
            _div.col_sm_10 do
              _input.form_control.name name: 'msg', required: false, placeholder: 'commit message; will be prefixed by: Uploaded by Whimsy'
            end
          end
          _div.form_group do
            _div.col_sm_offset_2.col_sm_10 do
              _input.btn.btn_default type: 'submit', value: 'Upload'
            end
          end
        end
      end
      _div.well.well_lg do
        if _.post?
          if @url !~ %r{^https://(dist|svn)\.apache\.org/\S+$}
              raise ArgumentError.new("Invalid SVN URL!")
          end
          msg = "Uploaded by Whimsy: #{@msg}"
          # The source is StringIO for smaller files, Tempfile for larger ones
          # The cutoff seems to be somewhere between 18k and 27k
          if @source.instance_of? Tempfile
            data = @source
          else
            data = @source.read
          end
          name = @source.original_filename.gsub(/[^-.\w]/, '_').sub(/^\.+/, '_')
          ASF::Auth.decode(env = {})
          # data can either be a string or a Tempfile
          if ASF::SVN.create_(@url, name, data, msg, env, _) == 0
            _p "Successfully added #{name} to #{@url} !"
          else
            _p "File #{name} already exists at #{@url} ?"
          end
        end
      end
    end
  end
end

