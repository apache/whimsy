#!/usr/bin/env ruby
PAGETITLE = "Mapping Committer IDs In JIRA and Confluence" # Wvisible:tools 

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'tmpdir'
require 'json'
require 'time'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'whimsy/asf'

COMMITTERID = 'cid'
JIRAHAS = 'jirahas'
JIRA = 'jira'
JIRAOTHER = 'jiraother'
CONFLUENCEHAS = 'confhas'
CONFLUENCE = 'conf'
CONFLUENCEOTHER = 'confother'
SUBMITTED_AT = 'submitted'

MAPPING_DIR = 'https://svn.apache.org/repos/private/committers/tools/ldap/'
MAPPING_FILE = 'ldap-map.json'

JIRAHAS_VALS = {
  'y' => 'Yes - I have one JIRA ID',
  'n' => 'No - I do not have a JIRA ID',
  'm' => 'I have multiple JIRA IDs',
}
CONFLUENCEHAS_VALS = {
  'y' => 'Yes - I have one Confluence ID',
  'n' => 'No - I do not have a Confluence ID',
  'm' => 'I have multiple Confluence IDs',
}

# Display a single input control; or if rows: then a textarea
# TODO Move to utility class and update committers/tm-report
def emit_input(
  name: nil,
  label: 'Enter string',
  type: 'text',
  rows: nil, # If rows, then is a textarea instead of input
  value: '',
  required: false,
  readonly: false,
  icon: nil,
  iconlabel: nil,
  iconlink: nil,
  placeholder: nil,
  pattern: nil,
  helptext: nil
  )
  return unless name
  tagname = 'input'
  tagname = 'textarea' if rows
  aria_describedby = "#{name}_help" if helptext
  _div.form_group do
    _label.control_label.col_sm_3 label, for: "#{name}"
    _div.col_sm_9 do
      _div.input_group do
        if pattern
          _.tag! tagname, class: 'form-control', name: "#{name}", id: "#{name}",
          type: "#{type}", pattern: "#{pattern}", placeholder: "#{placeholder}", value: value,
          aria_describedby: "#{aria_describedby}", required: required, readonly: readonly
        else
          _.tag! tagname, class: 'form-control', name: "#{name}", id: "#{name}",
          type: "#{type}", placeholder: "#{placeholder}", value: value,
          aria_describedby: "#{aria_describedby}", required: required, readonly: readonly
        end
        if iconlink
          _div.input_group_btn do
            _a.btn.btn_default type: 'button', aria_label: "#{iconlabel}", href: "#{iconlink}", target: 'whimsy_help' do
              _span.glyphicon class: "#{icon}", aria_label: "#{iconlabel}"
            end
          end
        elsif icon
          _span.input_group_addon do
            _span.glyphicon class: "#{icon}", aria_label: "#{iconlabel}"
          end
        end
      end
      if helptext
        _span.help_block id: "#{aria_describedby}" do
          _ "#{helptext}"
        end
      end
    end
  end
end

# Display form and Submit button, including any existing mapping data
# @param formdata - hash of any existing data from MAPPING_FILE, or user's previously-submitted data (if error)
def emit_form(formdata: {})
  if formdata[JIRA] || formdata[CONFLUENCE]
    title = 'Update your JIRA and Confluence IDs (previously submitted)'
    submit_title = 'Update Your ID Mapping'
  else
    title = 'Enter your JIRA and Confluence IDs'
    submit_title = 'Submit Your ID Mapping'
  end
  _whimsy_panel(title, style: 'panel-success') do
    _form.form_horizontal method: 'post' do
      _div.form_group do
        _label.control_label.col_sm_3 'Do you have an Apache JIRA ID?', for: JIRAHAS
        _div.col_sm_9 do
          _select.form_control name: JIRAHAS, id: JIRAHAS, required: true do
            _option value: ''
            _option "Yes - I have one JIRA ID", value: 'y', selected: "#{formdata[JIRAHAS] == 'y' ? 'selected': ''}"
            _option "No - I do not have a JIRA ID", value: 'n', selected: "#{formdata[JIRAHAS] == 'n' ? 'selected': ''}"
            _option "I use multiple JIRA IDs", value: 'm', selected: "#{formdata[JIRAHAS] == 'm' ? 'selected': ''}"
          end
        end
      end
      emit_input(label: 'Enter your Apache JIRA ID (if you have one)', name: JIRA, required: false,
        value: "#{formdata[JIRA]}", 
        helptext: "The JIRA ID used on issues.apache.org (usually same as committer ID)")
      emit_input(label: 'List any other JIRA IDs you personally use, one per line', name: JIRAOTHER, required: false,
        value: "#{formdata[JIRAOTHER]}",
        rows: 3, helptext: "Remember: these should only be personal IDs you use, not project ones.")
        
      _div.form_group do
        _label.control_label.col_sm_3 'Do you have an Apache Confluence ID?', for: CONFLUENCEHAS
        _div.col_sm_9 do
          _select.form_control name: CONFLUENCEHAS, id: CONFLUENCEHAS, required: true do
            _option value: ''
            _option "Yes - I have one Confluence ID", value: 'y', selected: "#{formdata[CONFLUENCEHAS] == 'y' ? 'selected': ''}"
            _option "No - I do not have a Confluence ID", value: 'n', selected: "#{formdata[CONFLUENCEHAS] == 'n' ? 'selected': ''}"
            _option "I use multiple Confluence IDs", value: 'm', selected: "#{formdata[CONFLUENCEHAS] == 'm' ? 'selected': ''}"
          end
        end
      end
      emit_input(label: 'Enter your Apache Confluence ID (if you have one)', name: CONFLUENCE, required: false,
        value: "#{formdata[CONFLUENCE]}", 
        helptext: "The Confluence ID used on cwiki.apache.org (usually same as committer ID)")
      emit_input(label: 'List any other Confluence IDs you personally use, one per line', name: CONFLUENCEOTHER, required: false,
        value: "#{formdata[CONFLUENCEOTHER]}",
        rows: 3, helptext: "Remember: these should only be personal IDs you use, not project ones.")
      
      emit_input(label: 'Your Apache Committer ID', name: COMMITTERID, readonly: true,
        value: formdata[COMMITTERID], icon: 'glyphicon-user', iconlabel: 'Committer ID')
      _div.col_sm_offset_3.col_sm_9 do
        _input.btn.btn_default type: 'submit', value: submit_title
      end
    end
  end
end

# Simplistic validation after POST
# @return true if data probably OK; false otherwise
def validate_form(formdata: {})
  errtxt = nil
  begin
    if nil == formdata[COMMITTERID]
      errtxt = "ERROR: Bogus submission, no COMMITTERID"
    elsif ('' == formdata[JIRAHAS]) || ('' == formdata[CONFLUENCEHAS])
      errtxt = "ERROR: You must answer Yes/No if you have JIRA or Confluence IDs"
    elsif (formdata[JIRAHAS] =~ /(y|m)/) && ('' == formdata[JIRA])
      errtxt = "ERROR: You must provide your JIRA ID"
    elsif (formdata[CONFLUENCEHAS] =~ /(y|m)/) && ('' == formdata[CONFLUENCE])
      errtxt = "ERROR: You must provide your Confluence ID"
    elsif (formdata[JIRAHAS] =~ /n/) && ('' != formdata[JIRA])
      errtxt = "ERROR: Do not provide JIRA ID if you answered No"
    elsif (formdata[CONFLUENCEHAS] =~ /n/) && ('' != formdata[CONFLUENCE])
      errtxt = "ERROR: Do not provide Confluence ID if you answered No"
    end
  rescue StandardError => e
    errtxt = "ERROR: validate_form threw: #{e}"
  end
  if errtxt
    _div.alert.alert_danger role: 'alert' do
      _h4 errtxt
    end
    return false
  else
    return true
  end
end

# Submit the committer's provided mapping of their own IDs
def submit_form(formdata: {})
  formdata[SUBMITTED_AT] = Time.now.iso8601
  rc = 999 # Ensure it's a bogus value
  Dir.mktmpdir do |tmpdir|
    tmpdir.untaint
    credentials = ['--username', $USER, '--password', $PASSWORD]
    _.system ['svn', 'checkout', MAPPING_DIR, tmpdir, ['--depth',  'files', '--no-auth-cache', '--non-interactive'], credentials]
    
    filename = File.join(tmpdir, MAPPING_FILE).untaint
    idmaps = JSON.parse(File.read(filename))
    # Add user data (may overwrite existing entry)
    idmaps[formdata[COMMITTERID]] = formdata
    # Sort file (to keep diff clean) and write it back
    idmaps = Hash[idmaps.keys.sort.map {|k| [k, idmaps[k]]}]
    File.write(filename, JSON.pretty_generate(idmaps))
    
    Dir.chdir tmpdir do
      rc = _.system ['svn', 'commit', filename, '--message', "#{formdata[COMMITTERID]} JIRA=#{formdata[JIRA]} Confluence=#{formdata[CONFLUENCE]}",
        ['--no-auth-cache', '--non-interactive'], credentials]
    end
  end

  if rc == 0
    _div.alert.alert_success role: 'alert' do
      _p do
        _span.strong 'ID Mapping successfully submitted'
        _ 'Thanks for helping out the Infra team with the future SSO consolidation!'
      end
    end
  else
    _div.alert.alert_danger role: 'alert' do
      _p do
        _span.strong 'Checking in your ID Mapping failed, see above for errors.'
      end
    end
  end
end

# Retrieve any existing mapping already provided
# @param cid - committer ID to lookup
# @return hash of mapping already entered; or nil
def get_mapping(cid)
  dir = ASF::SVN['ldap-map']
  filename = File.join(dir, MAPPING_FILE).untaint
  maps = JSON.parse(File.read(filename))
  if maps.has_key?(cid)
    return maps[cid]
  else
    return { COMMITTERID => cid }
  end
end

_html do
  _body? do
    _style :system
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Confirm your JIRA/Confluence user IDs',
      relatedtitle: 'More Useful Links',
      related: {
        "/committers/tools" => "Whimsy Tool Listing",
        "https://issues.apache.org/jira/secure/Dashboard.jspa" => "Apache JIRA Instance",
        "https://cwiki.apache.org/" => "Apache Confluence Instance",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code"
      },
      helpblock: -> {
        _div.alert.alert_danger role: 'alert' do
          _p do
            _span.strong 'ALPHA CODE - NOT READY FOR PRODUCTION USE'
          end
        end
        _p %{
          Apache Infra is improving our JIRA (issues.apache.org) and Confluence (cwiki.apache.org) tooling with single sign on, so that both 
          systems will use your Apache LDAP ID/password to logon - the same user ID used for 
          Subversion and other internal ASF systems.
        }
        _p "Please help test this tool by confirming your current JIRA and Confluence usernames now, before the switchover (planned for late 2018)."
      },
    ) do
      # Display depending if we're GET (new form) or POST (process & show results)
      if _.post?
        submission = {
          COMMITTERID => "#{@cid}",
          JIRAHAS => "#{@jirahas}",
          JIRA => "#{@jira}",
          JIRAOTHER => "#{@jiraother}",
          CONFLUENCEHAS => "#{@confhas}",
          CONFLUENCE => "#{@conf}",
          CONFLUENCEOTHER => "#{@confother}",
        }
        if validate_form(formdata: submission)
          submit_form(formdata: submission)
        else
          _div.alert.alert_danger role: 'alert' do
            _p "Your ID Mapping was NOT processed - please correct blanks/errors and Submit again."
          end
          emit_form(formdata: submission)
        end
      else
        person = ASF::Person.new($USER)
        emit_form(formdata: get_mapping(person.id))
      end
    end
  end
end
