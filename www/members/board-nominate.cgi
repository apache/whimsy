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

# Countdown until nominations for current meeting close
t_now = Time.now.to_i
t_end = Time.parse(ASF::MeetingUtil.nominations_close).to_i
nomclosed = t_now > t_end

def emit_form(title, prev_data)
  _whimsy_panel(title, style: 'panel-success') do
    _form.form_horizontal method: 'post' do
      _whimsy_forms_subhead(label: 'Nomination Form')
      field = 'availid'
      _whimsy_forms_input(
        label: 'Nominee availid', name: field,
        value: prev_data[field], helptext: 'Enter the availid of the potential board member'
      )
      _whimsy_forms_input(
        label: 'Nominated by', name: 'nomby', readonly: true, value: $USER
      )
      _whimsy_forms_input(
        label: 'Seconded by', name: 'secby', helptext: 'Optional comma-separated list of seconds'
      )
      field = 'statement'
      _whimsy_forms_input(label: 'Nomination Statement', name: field, rows: 10,
        value: prev_data[field], helptext: 'Reason for nomination'
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
  chk.nil? and return "Invalid or non-Member availid: #{uid}"
  already = ASF::MemberFiles.board_nominees
  return "Already nominated: #{uid} by #{already[uid]['Nominated by']}" if already.include? uid
  return 'OK'
end

# Handle submission (checkout board_nominations.txt, write form data, checkin file)
# @return true if we think it succeeded; false in all other cases
def process_form(formdata: {}, wunderbar: {})
  statement = formdata['statement']

  _h3 'Copy of nominators statement about the candidate'
  _pre statement

  _hr

  _h3 'Transcript of update to nomination file'
  uid = formdata['availid']
  entry = ASF::MemberFiles.make_board_nomination({
    availid: uid,
    nomby: $USER,
    secby: formdata['secby'],
    statement: statement
  })

  environ = Struct.new(:user, :password).new($USER, $PASSWORD)
  ASF::MemberFiles.update_board_nominees(environ, wunderbar, [entry], "+= #{uid}")
  return true
end

# Produce HTML
_html do
  _body? do # The ? traps errors inside this block
    _whimsy_body( # This emits the entire page shell: header, navbar, basic styles, footer
      title: PAGETITLE,
      subtitle: 'About This Script',
      related: {
        '/members/meeting' => 'Member Meeting FAQ and info',
        'board-nominations.cgi' => 'Board nominations cross-check',
        ASF::SVN.svnpath!('Meetings') => 'Official Meeting Agenda Directory'
      },
      helpblock: -> {
        _h3 'BETA - please report any errors at private@whimsical!'
        _p %{
          This form can be used to ADD entries to the board-nominations.txt file.
          This is currently for use by the Nominator only, and does not yet send a copy
          of the nomination to the members list.
          There is no support for updating an existing entry.
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
              _p.lead "Your nomination was submitted to svn."
              # TODO Also send mail to members@ with this data (to complete process)
            else
              _div.alert.alert_warning role: 'alert' do
                _p "SORRY! Your submitted form data failed process_form, please try again."
              end
            end
          else
            _div.alert.alert_danger role: 'alert' do
              _p "SORRY! Your submitted form data failed validate_form, please try again."
              _p valid
            end
          end
        else # if _.post?
          emit_form('Enter nomination data', {})
        end
      end
    end
  end
end
