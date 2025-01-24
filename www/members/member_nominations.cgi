#!/usr/bin/env ruby
PAGETITLE = "Add entries to nominated-members.txt" # Wvisible:meeting
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

# Countdown until nominations for current meeting close
t_now = Time.now.to_i
t_end = Time.parse(ASF::MeetingUtil.nominations_close).to_i
nomclosed = t_now > t_end

def emit_form(title, prev_data)
  _whimsy_panel(title, style: 'panel-success') do
    _form.form_horizontal method: 'post' do
      _whimsy_forms_subhead(label: 'Nomination Form')
      field = 'availid'
      _whimsy_forms_input(label: 'Nominee availid', name: field,
        value: prev_data[field], helptext: 'Enter the availid of the committer you are nominating for ASF Membership'
      )
      _whimsy_forms_input(label: 'Nominated by', name: 'nomby', readonly: true, value: $USER
      )
      _whimsy_forms_input(
        label: 'Seconded by', name: 'secby', helptext: 'Optional comma-separated list of seconds; only if you have confirmed with the seconds directly'
      )
      field = 'statement'
      _whimsy_forms_input(label: 'Nomination Statement', name: field, rows: 10,
        value: prev_data[field], helptext: 'Explain why you believe this person would make a good ASF Member, and what projects/communities they work on at the ASF'
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
  chk.nil? and return "Invalid availid suppiled: (#{uid})\n\nStatement:\n#{formdata['statement']}"
  # Allow renomination of Emeritus
  pubname = ASF::Person[uid].public_name
  chk && !chk.to_s.start_with?('Emeritus') and return "Your nominee #{pubname} (#{uid}) is already an ASF member!"
  already = ASF::MemberFiles.member_nominees
  return "Candidate (#{uid}) has already been nominated by #{already[uid]['Nominated by']}" if already.include? uid
  return 'OK'
end

# Handle submission (checkout user's apacheid.json, write form data, checkin file)
# @return true if we think it succeeded; false in all other cases
def process_form(formdata: {}, wunderbar: {})
  statement = formdata['statement']
  uid = formdata['availid']

  _h3 'Transcript of update to nomination file'
  entry = ASF::MemberFiles.make_member_nomination({
    availid: uid,
    nomby: $USER,
    secby: formdata['secby'],
    statement: statement
  })

  environ = Struct.new(:user, :password).new($USER, $PASSWORD)
  ASF::MemberFiles.update_member_nominees(environ, wunderbar, [entry], "+= #{uid}")
  return true
end

# Send email to members@ with this nomination's data
# Return true if we think mail was sent
def send_nomination_mail(formdata: {})
  uid = formdata['availid']
  public_name = ASF::Person.new(uid).public_name
  secby = formdata.fetch('secby', nil)
  nomseconds = ''
  if secby
    nomseconds = "Nomination seconded by: #{secby}"
  end
  mail_body = <<-MAILBODY
The following nomination for #{public_name} (#{uid}) as a New Member Candidate
has been added:

#{formdata['statement']}

#{nomseconds}

--
- #{$USER}"
  Sent by Whimsy; data in Meetings/current/nominated-members.txt

MAILBODY

  ASF::Mail.configure
  mail = Mail.new do
    to "asf@shanecurcuru.org" # FIXME TESTING
    from $USER
    subject "[MEMBER NOMINATION] #{ASF::Person.new(uid).public_name} (#{uid})\n"
    text_part do
      body mail_body
    end
  end
  mail.deliver!
  return "The following email was just sent on your behalf:\n\n#{mail_body}"

end

# Produce HTML
_html do
  _body? do # The ? traps errors inside this block
    _whimsy_body( # This emits the entire page shell: header, navbar, basic styles, footer
      title: PAGETITLE,
      subtitle: 'About This Script',
      related: {
        '/members/meeting' => 'Member Meeting FAQ and info',
        '/members/memberless-pmcs' => 'PMCs with no/few ASF Members',
        '/members/watch' => 'Watch list for potential Member candidates',
        'nominations.cgi' => "Member nominations cross-check - ensuring nominations get on the ballot, etc.",
        ASF::SVN.svnpath!('Meetings') => 'Official Meeting Agenda Directory'
      },
      helpblock: -> {
        _h3 'BETA - please report any errors to the Whimsy PMC!'
        _p %{
          This form can be used to nominate new candidates for ASF Membership if they are already committers.
          It automatically adds an entry to to the nominated-members.txt file,
          and then will send an email to the members@ list with your nomination.
          There is currently no support for updating an existing entry or for adding seconds.
        }
      }
    ) do

      if nomclosed
        _h1 'Nominations are now closed!'
      else
        _h3 "Nominations close in #{ASFTime.secs2text(t_end - t_now)} at #{Time.at(t_end).utc}"
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
              _p.lead "Your nomination was submitted to svn; now sending email."
              mailval = send_nomination_mail(formdata: submission)
              _p mailval
            else
              _div.alert.alert_danger role: 'alert' do
                _p do
                  _span.strong "ERROR: Form data invalid in process_form(), update was NOT submitted! Data submitted:"
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
          emit_form('Enter one New Member nomination', {})
        end
      end
    end
  end
end
