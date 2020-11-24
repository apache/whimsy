#!/usr/bin/env ruby
PAGETITLE = "Apache Trademark Misuse Reporting Form"
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'whimsy/asf/rack'
require 'whimsy/asf'
require 'whimsy/public'
require 'mail'
require 'date'
require 'json'
require 'yaml'

BRANDLIST = 'Apache Brand Management <trademarks@apache.org>'

FORM_FIELDS = %w(
reporter
reporteremail
project
url
phrase
type
effect
involved
description
)
MISUSE_TYPES = {
  'product' => 'Software product',
  'services' => 'Services around software (hosting, cloud, development) ',
  'events' => 'Event branding or websites',
  'domains' => 'Domain names',
  'consulting' => 'Consulting, training, or similar activities',
  'merchandise' => 'Non-computer merchandise (apparel, stickers, etc.)',
  'attribution' => 'Without providing trademark attribution',
  'other' => 'Any other kind of potential misuse'
}
MISUSE_EFFECT = {
  'confusion' => 'Viewers could be confused who makes the software product',
  'affiliation' => 'Viewers could believe other party is affiliated with the project',
  'control' => 'Viewers could believe other party controls or manages the project',
  'disparage' => 'Puts the Apache project brand in a bad light',
  'exclusive' => 'Viewers could believe other party has exclusive relationship with the project',
  'notsure' => "Not sure; just doesn't feel right"
}
# Display a single input control; or if rows then a textarea
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
    _label.control_label.col_sm_3 label, for: name
    _div.col_sm_9 do
      _div.input_group do
        if pattern
          _.tag! tagname, class: 'form-control', name: name, id: name,
          type: type, pattern: pattern, placeholder: placeholder, value: value,
          aria_describedby: aria_describedby, required: required, readonly: readonly
        else
          _.tag! tagname, class: 'form-control', name: name, id: name,
          type: type, placeholder: placeholder, value: value,
          aria_describedby: aria_describedby, required: required, readonly: readonly
        end
        if iconlink
          _div.input_group_btn do
            _a.btn.btn_default type: 'button', aria_label: iconlabel, href: iconlink, target: 'whimsy_help' do
              _span.glyphicon class: icon, aria_label: iconlabel
            end
          end
        elsif icon
          _span.input_group_addon do
            _span.glyphicon class: icon, aria_label: iconlabel
          end
        end
      end
      if helptext
        _span.help_block id: aria_describedby do
          _ helptext
        end
      end
    end
  end
end

# Display the form
def emit_form()
  # Store auth so we know Apache ID of submitter
  user = ASF::Auth.decode(env = {})
  docket = JSON.parse(File.read(File.join(ASF::SVN['brandlist'], 'docket.json'))) # To annotate pmcs with (R) symbol
  committees = Public.getJSON('committee-info.json')['committees']

  _whimsy_panel("Report A Potential Misuse Of Apache\u00AE Brands", style: 'panel-success') do
    _form.form_horizontal method: 'post' do
      _div.form_group do
        _label.control_label.col_sm_3 'Apache project this report is about', for: 'project'
        _div.col_sm_9 do
          _select.form_control name: 'project', id: 'project', required: true do
            _option value: ''
            committees.each do |pmc, entry|
              if entry['pmc']
                display_name = entry['display_name']
                if docket[pmc]
                  _option "#{display_name} \u00AE", value: pmc
                else
                  _option "#{display_name} \u2122", value: pmc
                end
              end
            end
          end
        end
      end
      emit_input(label: 'URL showing the misuse', name: 'url', required: true,
        pattern: '.*://.*|.*@.*', placeholder: 'http://company.com/page.html',
        icon: 'glyphicon-link', iconlabel: 'Must be a URL', type: 'url',
        helptext: 'Provide a valid URL that shows an example of this misuse')

      emit_input(label: 'Specific phrase or sentence showing misuse', name: 'phrase', required: true,
        icon: 'glyphicon-question-sign', iconlink: 'https://www.apache.org/foundation/marks/reporting#issues',
        helptext: "Copy the specific text showing the use of the Apache brand that may be a problem (if possible to copy)")

      _div.form_group do
        _label.control_label.col_sm_3 'What type of product or service is the misuse with?', for: 'type'
        _div.col_sm_9 do
          _select.form_control name: 'type', id: 'type', required: true do
            _option value: ''
            MISUSE_TYPES.each do |val, desc|
              _option desc, value: val
            end
          end
        end
      end
      _div.form_group do
        _label.control_label.col_sm_3 'What effect might this misuse have on new users?', for: 'effect'
        _div.col_sm_9 do
          _select.form_control name: 'effect', id: 'effect' do
            _option value: ''
            MISUSE_EFFECT.each do |val, desc|
              _option desc, value: val
            end
          end
        end
      end

      emit_input(label: 'Description of misuse - why you believe this is improper', name: 'description', required: true,
        rows: 3, icon: 'glyphicon-question-sign', iconlink: 'https://www.apache.org/foundation/marks/resources',
        helptext: "Briefly describe in your own words why this use doesn't give proper credit to the Apache project")

      _div.form_group do
        _label.control_label.col_sm_3 'Do you know if individual(s) from this company (if any) are involved in this Apache project? (optional)', for: 'involved'
        _div.col_sm_9 do
          _select.form_control name: 'involved', id: 'involved' do
            _option value: ''
            _option "Yes - regularly", value: 'yes-regular'
            _option "Yes - sometimes", value: 'yes-some'
            _option "Yes - rarely", value: 'yes-rare'
            _option "No - not apparently", value: 'no'
            _option "Don't know", value: 'unknown'
          end
        end
      end
      emit_input(label: 'Committer ID of Reporter', name: 'reporter', readonly: true,
        value: user.id, icon: 'glyphicon-user', iconlabel: 'Committer ID')
      emit_input(label: 'Committer Email of Reporter', name: 'reporteremail', readonly: true,
        value: "#{user.public_name} (whimsy) <#{user.id}@apache.org>", icon: 'glyphicon-user', iconlabel: 'Committer Email')

      _div.col_sm_offset_3.col_sm_9 do
        _input.btn.btn_default type: 'submit', value: 'Submit Report'
      end
    end
  end
end

# Validation as needed within the script
def validate_form(_formdata: {})
  true # Futureuse
end

# Mail this report and alert user
def send_form(formdata: {})
  # Build the mail to be sent
  frm = formdata['reporteremail']
  subject = "[FORM] Misuse Report about #{formdata['project']}"
  pmc_list = ASF::Committee.find(formdata['project']).mail_list
  cc_list = ["private@#{pmc_list}.apache.org", frm]
  to_list = BRANDLIST

  if true # TESTING mode
    to_list = "asf@shanecurcuru.org"
    cc_list = ''
  end # TESTING mode

  ASF::Mail.configure
  mail = Mail.new do
    from  frm
    return_path BRANDLIST
    to      to_list
    cc      cc_list
  end
  mail.header['X-Mailer'] = 'whimsy/www/committer/tm-report(0.0)'
  mail.subject = subject
  mail.body = formdata.to_yaml
  begin
    mail.deliver!
  rescue Exception => e
    formdata['errors'] = "Bogosity! mail.deliver raised: #{e.message[0..255]}"
  end

  # Tell user what we did
  _div.well.well_lg do
    _div.bg_danger "BETA - THIS FORM IS NOT COMPLETE YET - DEBUGGING - formdata we would have mailed out"
    formdata['to'] = to_list
    formdata['cc'] = cc_list
    formdata['from'] = frm
    formdata['subject'] = subject
    _div.bg_info formdata.to_yaml
  end
  _div.well.well_lg do
    _div.bg_danger "BETA - THIS FORM IS NOT COMPLETE YET - DEBUGGING - Mail data that was sent (debug=to Shane)"
    _pre.email mail.to_s
  end
end

_html do
  _body? do
    _whimsy_body(
    title: PAGETITLE,
    subtitle: 'How To Report Brand Misuses',
    related: {
      'https://www.apache.org/foundation/marks/reporting' => 'Trademark Reporting Guidelines',
      'https://www.apache.org/foundation/marks/resources' => 'Apache Trademark Policy Site Map',
      '/brand/list' => 'Comprehensive List Of Apache Trademarks'
    },
    helpblock: -> {
      _p.bg_danger %{
        BETA: This tool is not implemented yet! But please feel free check it out and submit TEST reports.
      }
      _p %{
        If you believe you have found a potential misuse or infringement of
        any Apache brand or trademark, please use this form to report it.
      }
      _p do
        _ 'Reviewing the '
        _a 'Trademark Reporting Guidelines', href: 'https://www.apache.org/foundation/marks/reporting#kinds', target: 'whimsy_help'
        _ ' while you fill out this form is highly recommended.'
      end
    }
    ) do
      # Display data to the user, depending if we're GET (new form) or POST (show results)
      if _.post?
        submission = {
          'project' => @project,
          'url' => @url,
          'phrase' => @phrase,
          'type' => @type,
          'description' => @description,
          'reporter' => @reporter,
          'reporteremail' => @reporteremail
        }
        if validate_form(formdata: submission)
          send_form(formdata: submission)
          _a.btn.btn_default 'Submit another report?', href: '/committers/report'
        else
          _h6 "TO BE DONE - redisplay form with user's data in it!"
        end
      else
        emit_form
      end
    end
  end
end

