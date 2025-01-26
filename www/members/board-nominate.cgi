#!/usr/bin/env ruby
PAGETITLE = "Add entries to board_nominations.txt file" # Wvisible:meeting
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'time'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'whimsy/asf/forms'
require 'whimsy/asf/member-files'
require 'whimsy/asf/wunderbar_updates'
require 'whimsy/asf/meeting-util'
require 'whimsy/asf/time-utils'
require 'mail'

MAILING_LIST = 'gnomes@infra.apache.org'
NOMINATION_FILE = 'board_nominations.txt'

def emit_form(title, prev_data)
  _whimsy_panel(title, style: 'panel-success') do
    _form.form_horizontal method: 'post' do
      _whimsy_forms_subhead(label: 'Director Nomination Form')
      field = 'availid'
      _whimsy_forms_input(
        label: 'Nominee availid', name: field,
        value: prev_data[field], helptext: 'Enter the availid of the ASF committer you are nominating for the board'
      )
      _whimsy_forms_input(
        label: 'Nominated by', name: 'nomby', readonly: true, value: $USER
      )
      _whimsy_forms_input(
        label: 'Seconded by', name: 'secby', helptext: 'Optional comma-separated list of seconds; only if you have confirmed with the seconds directly'
      )
      field = 'statement'
      _whimsy_forms_input(label: 'Nomination Statement', name: field, rows: 10,
        value: prev_data[field], helptext: 'Explain why you believe this person would be a good Director'
      )
      _whimsy_forms_submit
    end
  end
end

# Validation as needed within the script
# Returns: 'OK' or a text message describing the problem
def validate_form(formdata: {})
  uid = formdata['availid']
  chk = ASF::Person[uid]&.asf_member?
  chk.nil? and return "Invalid availid or non-Member suppiled: (#{uid})\n\nStatement:\n#{formdata['statement']}"
  already = ASF::MemberFiles.board_nominees
  return "Candidate #{uid} has already been nominated by #{already[uid]['Nominated by']}" if already.include? uid
  return 'OK'
end

# Handle submission (checkout board_nominations.txt, write form data, checkin file)
# @return true if we think it succeeded; false in all other cases
def process_form(formdata: {}, wunderbar: {})
  _h3 "Transcript of update to nomination file #{NOMINATION_FILE}"
  entry = ASF::MemberFiles.make_board_nomination({
    availid: formdata['availid'],
    nomby: formdata['nomby'],
    secby: formdata['secby'],
    statement: formdata['statement']
  })

  environ = Struct.new(:user, :password).new($USER, $PASSWORD)
  ASF::MemberFiles.update_board_nominees(environ, wunderbar, [entry], "+= #{formdata['availid']}")
  return true
end

# Send email to members@ with this nomination's data
# Return status string if we think mail was sent
def send_nomination_mail(formdata: {})
  uid = formdata['availid']
  nomby = formdata['nomby']
  public_name = ASF::Person.new(uid).public_name
  secby = formdata.fetch('secby', nil)
  secby.nil? ? nomseconds = '' : nomseconds = "Nomination seconded by: #{secby}" unless secby.nil?
  mail_body = <<-MAILBODY
This nomination for #{public_name} (#{uid}) as a Director
Nominee has been added:

#{formdata['statement']}

#{nomseconds}

--
- #{ASF::Person[nomby].public_name}
  Email generated by Whimsy (#{File.basename(__FILE__)})

MAILBODY

  ASF::Mail.configure
  mail = Mail.new do
    to MAILING_LIST
    bcc 'notifications@whimsical.apache.org'
    from "#{ASF::Person[nomby].public_name} <#{nomby}@apache.org>"
    subject "[BOARD NOMINATION] #{ASF::Person.new(uid).public_name} (#{uid})"
    text_part do
      body mail_body
    end
  end
  mail.deliver!
  return "The following email was sent to #{MAILING_LIST}:\n\n#{mail_body}"
end

# Produce HTML
_html do
  _body? do
    # Countdown until nominations for current meeting close
    latest_meeting_dir = ASF::MeetingUtil.latest_meeting_dir
    timelines = ASF::MeetingUtil.get_timeline(latest_meeting_dir)
    t_now = Time.now.to_i
    t_end = Time.parse(timelines['nominations_close_iso']).to_i
    nomclosed = t_now > t_end
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'About This Script',
      related: {
        '/members/meeting' => 'Member Meeting FAQ and info',
        'board-nominations.cgi' => 'Board nominations cross-check',
        ASF::SVN.svnpath!('Meetings') => 'Official Meeting Agenda Directory'
      },
      helpblock: -> {
        _h3 'TESTING - please report any errors at private@whimsical!'
        _b "For: #{timelines['meeting_type']} Meeting on: #{timelines['meeting_iso']}"
        _p %Q{
          This form can be used to nominate candidates for the ASF Board of Director election if they are already Members.
          It automatically adds an entry to the #{NOMINATION_FILE} file,
          and then will send an email to the members@ list with your nomination.
          There is currently no support for updating an existing entry or for adding seconds; use SVN for that.
        }
      }
    ) do
      if nomclosed
        _h1 'Nominations are now closed!'
      else
        _h3 "Nominations close in #{ASFTime.secs2text(t_end - t_now)} at #{Time.at(t_end).utc} for Meeting: #{timelines['meeting_iso']}"
      end

      _div id: 'nomination-form' do
        if _.post?
          unless nomclosed
            submission = _whimsy_params2formdata(params)
            valid = validate_form(formdata: submission)
          end
          if nomclosed
            _div.alert.alert_warning role: 'alert' do
              _p "Nominations have closed"
            end
          elsif valid == 'OK'
            if process_form(formdata: submission, wunderbar: _)
              _div.alert.alert_success role: 'alert' do
                _p "Your nomination was submitted to svn; now sending email to #{MAILING_LIST}."
              end
              mailval = send_nomination_mail(formdata: submission)
              _pre mailval
            else
              _div.alert.alert_danger role: 'alert' do
                _p do
                  _span.strong "ERROR: Form data invalid in process_form(), update was NOT submitted!"
                  _br
                  _ "#{submission}"
                end
              end
            end
          else
            _div.alert.alert_danger role: 'alert' do
              _p do
                _span.strong "ERROR: Form data invalid in validate_form(), update was NOT submitted!"
                _br
                _p valid
              end
            end
          end
        else # if _.post?
          emit_form('Enter your nomination for a Director Candidate', {})
        end
      end
    end
  end
end
