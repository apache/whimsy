#!/usr/bin/env ruby
PAGETITLE = "Create/Update Your Mentor Record" # Wvisible:members
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'whimsy/asf'
require 'wunderbar/markdown'
require 'whimsy/asf/rack'
require 'json'
require 'tzinfo'
require_relative 'mentor-format'
require 'whimsy/asf/forms'

# Convenience function
def emit_mentor_input(field, mdata, uimap, icon, req: false)
  _whimsy_forms_input(label: uimap[field][0], name: field, required: req,
    icon: icon, value: (mdata[field] ? mdata[field] : ''),
    helptext: uimap[field][1]
  )
end

# Display the form for user's mentor record (custom function to mentor data structure)
def emit_form(apacheid, mdata, button_help, uimap)
  title = mdata.empty?() ? 'Volunteer to Mentor a New ASF Member' : 'Update your Mentor Record'
  _whimsy_panel("#{title} (#{apacheid})", style: 'panel-success') do
    _form.form_horizontal method: 'post' do
      if mdata.has_key?(MentorFormat::ERRORS)
        _div.alert.alert_danger role: 'alert' do
          _p 'There was an error parsing the .json; you might need to manually edit it instead:'
          _p.text_error mdata[MentorFormat::ERRORS]
        end
      end

      _div.form_group do
        _label.col_sm_offset_3.col_sm_9.strong.text_left 'How Mentees Should Work With You'
      end
      emit_mentor_input('contact', mdata, uimap, 'glyphicon-bullhorn', req: true)
      field = 'timezone'
      _whimsy_forms_select(label: uimap[field][0], name: field,
        values: (mdata[field] ? mdata[field] : ''),
        options: MentorFormat::TZ.sort,
        icon: 'glyphicon-time', iconlabel: 'clock',
        helptext: uimap[field][1]
      )
      emit_mentor_input('availability', mdata, uimap, 'glyphicon-hourglass')
      field = 'prefers'
      _whimsy_forms_select(label: uimap[field][0], name: field, multiple: true,
        values: (mdata[field] ? mdata[field] : ''),
        options: MentorFormat::PREFERS_TYPES,
        icon: 'glyphicon-ok-sign', iconlabel: 'ok-sign',
        helptext: uimap[field][1]
      )
      field = 'languages'
      _whimsy_forms_select(label: uimap[field][0], name: field, multiple: true,
        values: (mdata[field] ? mdata[field] : ''),
        options: MentorFormat::LANGUAGES,
        icon: 'glyphicon-globe', iconlabel: 'globe',
        helptext: uimap[field][1]
      )

      _div.form_group do
        _label.col_sm_offset_3.col_sm_9.strong.text_left 'What You Could Help Mentees With'
      end
      emit_mentor_input('experience', mdata, uimap, 'glyphicon-certificate')
      emit_mentor_input('available', mdata, uimap, 'glyphicon-plus-sign')
      emit_mentor_input('mentoring', mdata, uimap, 'glyphicon-minus-sign')

      _div.form_group do
        _label.col_sm_offset_3.col_sm_9.strong.text_left 'More About You Personally'
      end
      emit_mentor_input('homepage', mdata, uimap, 'glyphicon-console')
      emit_mentor_input('pronouns', mdata, uimap, 'glyphicon-user')
      field = 'aboutme'
      _whimsy_forms_input(label: uimap[field][0], name: field, rows: 3,
        icon: 'glyphicon-info-sign', value: (mdata[field] ? mdata[field] : ''),
        helptext: uimap[field][1]
      )

      _div.form_group do
        _label.col_sm_offset_3.col_sm_9.strong.text_left 'Temporarily Opt Out From Any NEW Mentees'
        _label.control_label.col_sm_3 'Not Accepting New Mentees', for: MentorFormat::NOTAVAILABLE
        _div.col_sm_9 do
          _div.input_group do
            _label MentorFormat::NOTAVAILABLE do
              args = { type: 'checkbox', id: MentorFormat::NOTAVAILABLE, name: MentorFormat::NOTAVAILABLE, value: MentorFormat::NOTAVAILABLE }
              args[:checked] = true if mdata[MentorFormat::NOTAVAILABLE]
              _input ' Stop accepting NEW Mentees', args
            end
          end
          _span.help_block do
            _ "Select checkbox to no longer be listed in active mentor list (you can still work with existing Mentees)."
          end
        end
      end

      _div.col_sm_offset_3.col_sm_9 do
        _span.text_info button_help
        _br
        _input.btn.btn_default type: 'submit', value: 'Update Your Mentor Data'
      end
    end
  end
end

# Validation as needed within the script
def validate_form(formdata: {})
  # Scrub one key if it's blank (only leave it if set to a value)
  if formdata.has_key?(MentorFormat::NOTAVAILABLE) && formdata[MentorFormat::NOTAVAILABLE] == ''
    formdata.delete(MentorFormat::NOTAVAILABLE)
  end
  return true # TODO: Futureuse
end

# Handle submission (checkout user's apacheid.json, write form data, checkin file)
# @return true if we think it succeeded; false in all other cases
def send_form(formdata: {})
  rc = 999
  fn = "#{$USER}.json"
  mentor_update = JSON.pretty_generate(formdata) + "\n"
  _div.well do
    _p.lead "Updating your mentor record #{fn} to be:"
    _pre mentor_update
  end

  Dir.mktmpdir do |tmpdir|
    credentials = {user: $USER, password: $PASSWORD}
    # TODO: investigate if we should to --depth empty and attempt to get only that mentor's file
    ASF::SVN.svn_('checkout', [MentorFormat::MENTORS_SVN, tmpdir], _, credentials)
    Dir.chdir tmpdir do
      if File.exist? fn
        File.write(fn, mentor_update + "\n")
        ASF::SVN.svn_('status','.', _)
        message = "Updating my mentoring data (whimsy)"
      else
        File.write(fn, mentor_update + "\n")
        ASF::SVN.svn_('add', fn, _)
        message = "#{$USER} += mentoring volunteer (whimsy)"
      end
      rc = ASF::SVN.svn_('commit', fn, _, {msg: message}.merge(credentials)]
    end
  end

  if rc == 0
    _div.alert.alert_success role: 'alert' do
      _p do
        _span.strong 'Your mentor update was submitted, and will be live within a few minutes.  Thanks for volunteering!'
      end
    end
    return true
  else
    _div.alert.alert_danger role: 'alert' do
      _p do
        _span.strong 'SVN Update Failed, see above for details; contact dev@whimsical.apache.org for help.  Alternately, edit your Mentor file directly in SVN: '
        _a "#{MentorFormat::MENTORS_SVN}#{$USER}.json", href: "#{MentorFormat::MENTORS_SVN}#{$USER}.json"
      end
    end
    return false
  end
end

# Read user's *.json from directory of mentor files
# @return user's current mentor data, or {} if none, or sets:
# myrecord[ERRORS] = "If any error occurred on read/parse"
def read_myrecord(id)
  file = File.join(ASF::SVN['foundation_mentors'], "#{id}.json")
  if File.exist?(file)
    begin
      return JSON.parse(File.read(file))
    rescue StandardError => e
      return { MentorFormat::ERRORS => "ERROR:read_myrecord(#{file}) #{e.message} #{e.backtrace[0]}" }
    end
  else
    return {}
  end
end

# produce HTML
_html do
  _style :system
  _style %{
    .transcript {margin: 0 16px}
    .transcript pre {border: none; line-height: 0}
  }
  _body? do
    myrecord = read_myrecord($USER)
    intro = "You can use this form to update your existing Mentor record, which will be checked into #{MentorFormat::MENTORS_SVN}"
    header = 'Update Your Mentor Data (most fields optional)'
    button_help = "Pressing Update will update your existing Mentoring Record in #{MentorFormat::MENTORS_SVN}#{$USER}.json"
    if myrecord.empty?
      intro = "You can use this form to volunteer to Mentor other new ASF Members; when you submit your Mentoring Record will be checked into #{MentorFormat::MENTORS_SVN})"
      header = 'Enter Your Mentor Data (most fields optional)'
      button_help = "Pressing Update will checkin your Mentoring Record into #{MentorFormat::MENTORS_SVN}#{$USER}.json and list you as a volunteer mentor here: #{MentorFormat::MENTORS_LIST}##{$USER}"
    elsif myrecord.has_key?(MentorFormat::ERRORS)
      intro = "Your existing .json file has an error (see below), please work with the Whimsy PMC to fix it: #{MentorFormat::MENTORS_SVN}#{$USER}.json"
      header = 'There was an error either finding or JSON parsing your mentor record!'
      button_help = "ERROR: We couldn't properly parse your existing .json file, this form may not work properly."
    end
    uimap = MentorFormat.get_uimap(ASF::SVN['foundation_mentors'])
    _whimsy_body(
      title: PAGETITLE,
      subtitle: header,
      related: {
        MentorFormat::MENTORS_SVN => 'See All Mentors Data',
        '/members/mentors' => 'List Of Active Mentors',
        '/members/index/' => 'Other Member-Private Tools',
        'https://community.apache.org/' => 'Apache Community Development'
      },
      helpblock: -> {
        _p intro
        _p.text_warning 'Reminder: All Mentoring data is private to the ASF; only ASF Members can sign up here as Mentors or Mentees.'
      }
    ) do

      # Display data to the user, depending if we're GET (existing mentor record or just blank data) or POST (show SVN checkin results)
      if _.post?
        submission = {
          "timezone" => @timezone,
          "availability" => @availability,
          "contact" => @contact,
          "available" => @available,
          "mentoring" => @mentoring,
          "experience" => @experience,
          "pronouns" => @pronouns,
          "aboutme" => @aboutme,
          "homepage" => @homepage,
          # Multiple select fields
          "prefers" => _.params['prefers'],
          "languages" => _.params['languages']
        }
        if @notavailable
          submission['notavailable'] = @notavailable
        end
        if validate_form(formdata: submission)
          if send_form(formdata: submission)
            _p.lead "Thanks for volunteering to mentor other ASF Members!"
            _p do
              _ "Your record will now show up on the list of active mentors (unless you had checked 'notavailable'). "
              _a 'See the current list of active mentors', href: '/members/mentors'
            end
          end
        else
          _div.alert.alert_danger role: 'alert' do
            _p do
              _span.strong "WARNING: Form data invalid, update was NOT submitted! "
              _br
              _ "There was a validation error with your form submission; please contact dev@whimsical.apache.org with a bug report."
            end
          end
        end
      else # if _.post?
        emit_form($USER, myrecord, button_help, uimap)
      end
    end
  end
end
