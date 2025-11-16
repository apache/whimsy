#!/usr/bin/env ruby
PAGETITLE = "Update Affiliations.txt" # Wvisible:members,officers
# Note: PAGETITLE must be double quoted

# Page to allow arbitrary updates to affiliations.txt, without needing to install or know SVN

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'whimsy/asf/rack'
require 'whimsy/asf/forms'

user = ASF::Auth.decode(env = {})
unless user.asf_chair_or_member?
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

source = File.join(ASF::SVN.svnurl!('officers'),'affiliations.txt')

def emit_form(url, revision, original, updated, diff, env)
  
  _whimsy_panel(url, style: 'panel-success') do
    _form.form_horizontal method: 'post' do
      _input type: 'hidden', name: 'original', value: original
      field = 'revision'
      _whimsy_forms_input(label: 'Revision', name: field, id: field,
        value: revision, readonly: true
      )
      field = 'updated'
      _whimsy_forms_input(label: 'Content', name: field, id: field, rows: 15,
        value: updated || original
      )
      if diff
        field = 'difference'
        rows = nil
        rows = 5 if diff.size > 0
        _whimsy_forms_input(label: 'Difference', name: field, id: field, rows: rows, readonly: true, 
          value: diff.size > 0 ? diff : '[No differences found]'
        )
      end
      _div.col_sm_offset_3.col_sm_9 do
        _input.btn.btn_default type: 'submit', label: 'Diff', name: 'Submit', value: 'Diff', helptext: 'Show diff'
        _input.btn.btn_default type: 'submit', label: 'Commit', name: 'Submit', value: 'Commit', helptext: 'Commit diff'
      end
    end
  end
end

# Handle submission
def process_form(source, env, formdata: {})
  if formdata['Submit'] == 'Diff'
    require 'tempfile'
    require 'open3'
    Tempfile.create('original_') do |f|
      Tempfile.create('updated_') do |g|
        f.write(formdata['original'])
        f.close
        g.write(formdata['updated'])
        g.close
        diff, err, rc = Open3.capture3('diff', '-u', '-L', 'original',  '-L' 'updated', f.path, g.path)
        if err.empty? and (rc.exitstatus == 1 or rc.exitstatus == 0)
          emit_form(source, formdata['revision'], formdata['original'], formdata['updated'], diff, env)
        else
          _p err
        end
      end
    end
    return nil
  end
  begin
    _p class: 'system' do
      ASF::SVN.updatefile(source, "Update my affiliation", env, _, formdata['revision']) do |_original|
        formdata['updated']
      end
    end
    return true
  rescue Exception => e
    Wunderbar.error "Error updating #{source}: #{e.to_s}"
    return e.to_s
  end
end

# Produce HTML
_html do
  _body? do # The ? traps errors inside this block
    _whimsy_body( # This emits the entire page shell: header, navbar, basic styles, footer
      title: PAGETITLE,
      subtitle: 'About',
      relatedtitle: 'More Useful Links',
      related: {
        "/committers/tools" => "Whimsy Tool Listing",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code"
      },
      helpblock: -> {
        _p %{
          Update a file in SVN using a temporary checkout.
          The revision of the source is checked to ensure that the file has not been changed in the meantime.
        }
        _p do
          _b 'Note that no checks are performed, so please be careful to only update your data.'
          _br
          _ 'Please use the Diff button to check the changes that will be applied.'
        end
      },
      breadcrumbs: {
        update_file: ENV['SCRIPT_NAME']
      }
    ) do
      _div id: 'example-form' do
        if _.post?
          ret = process_form(source, env, formdata: _whimsy_params2formdata(params))
          # may be true, nil or error messahe
          if ret == true
            _p.lead "Successful"
          elsif !ret.nil?
            _div.alert.alert_warning role: 'alert' do
              _p "SORRY! Your commit failed, please try again."
              _p ret
            end
          end
        else # if _.post?
          revision, original = ASF::SVN.getfile(source, env)
          updated = diff = nil
          emit_form(source, revision, original, updated, diff, env)
        end
      end
    end
  end
end
