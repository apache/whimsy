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
require_relative 'mentors'
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
      _div.form_group do
        _label.col_sm_offset_3.col_sm_9.strong.text_left 'How Mentees Should Work With You'
      end
      emit_mentor_input('contact', mdata, uimap, 'glyphicon-bullhorn', req: true)
      field = 'timezone'
      _whimsy_forms_select(label: uimap[field][0], name: field, 
        value: (mdata[field] ? mdata[field] : ''),
        options: MentorFormat::TZ,
        icon: 'glyphicon-time', iconlabel: 'clock', 
        helptext: uimap[field][1]
      )
      emit_mentor_input('availability', mdata, uimap, 'glyphicon-hourglass')
      emit_mentor_input('prefers', mdata, uimap, 'glyphicon-ok-sign')
      emit_mentor_input('languages', mdata, uimap, 'glyphicon-globe')

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
      emit_mentor_input('aboutme', mdata, uimap, 'glyphicon-info-sign')
      emit_mentor_input('homepage', mdata, uimap, 'glyphicon-console')

      # TODO Add 'notavailable' checkbox, with value
      
      _div.col_sm_offset_3.col_sm_9 do
        _span.text_info button_help
        _br
        if mdata.has_key?([MentorFormat::ERRORS])
          _span.text_warning 'There was an error parsing the .json; you might need to manually edit it instead.'
          _br
        end
        _input.btn.btn_default type: 'submit', value: 'Update Your Mentor Data'
      end
    end
  end
end
  
# Validation as needed within the script
def validate_form(formdata: {})
  true # Futureuse
end

# Handle submission (checkout user's apacheid.json, write form data, checkin the file)
def send_form(formdata: {})
  true # Futureuse
end

# Read user's *.json from directory of mentor files
# @return user's current mentor data, or {} if none, or sets:
# myrecord[ERRORS] = "If any error occoured on read/parse"
def read_myrecord(id)
  file = File.join(ASF::SVN['foundation_mentors'], "#{id}.json").untaint
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
  _body? do
    myrecord = read_myrecord($USER)
    intro = "You can use this form to update your existing Mentor record, which will get checked into #{MentorFormat::MENTORS_SVN}"
    header = 'Update Your Mentor Data (most fields optional)'
    button_help = "Pressing Update will attempt to checkin your data into #{MentorFormat::MENTORS_SVN}#{$USER}.json"
    if myrecord.empty?
      intro = "You can use this form to volunteer to mentor other new ASF Members; when you submit your listing will be checked int #{MentorFormat::MENTORS_SVN})"
      header = 'Enter Your Mentor Data (most fields optional)'
      button_help = "Pressing Update will checkin your data into #{MentorFormat::MENTORS_SVN}#{$USER}.json and list you as a volunteer mentor here: #{MentorFormat::MENTORS_LIST}##{$USER}"
    elsif myrecord.has_key?(MentorFormat::ERRORS)
      intro = "Your existing .json file has an error: #{myrecord[MentorFormat::ERRORS]}, please work with the Whimsy PMC to fix it: #{MentorFormat::MENTORS_SVN}#{$USER}.json"
      header = 'There was an error either finding or JSON parsing your mentor record!'
      button_help = "WARNING: #{myrecord[MentorFormat::ERRORS]} found parsing your .json, this form may not work properly."
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
        _div.alert.alert_warning role: "alert" do
          _span.strong 'DEBUG ALPHA SOFTWARE - UPDATES ARE NOT IMPLEMENTED.  To volunteer to be a mentor today, you will need to checkin your .json manually.'
        end
      }
    ) do
      # Display data to the user, depending if we're GET (existing mentor record or just blank data) or POST (show SVN checkin results)
      if _.post?
        submission = { # TODO make this a loop over uimap.keys
          "timezone" => "#{@timezone}",
          "availability" => "#{@availability}",
          "contact" => "#{@contact}",
          "prefers" => "#{@prefers}",
          "available" => "#{@available}",
          "mentoring" => "#{@mentoring}",
          "experience" => "#{@experience}",
          "languages" => "#{@languages}",
          "pronouns" => "#{@pronouns}",
          "aboutme" => "#{@aboutme}",
          "homepage" => "#{@homepage}"
        }
        _h6 "TODO: Your Submitted Data Was:"
        _p do
          _ul do
            uimap.keys.each do |field|
              _li do
                _span.text_primary "#{field}: "
                _ submission[field]
                _br
              end
            end
          end
        end
        if validate_form(formdata: submission)
          send_form(formdata: submission)
          _a.btn.btn_default 'TODO: SVN Checkin is not implented yet!', href: '#TODO'
        else
          _h6 "TODO: display validation error(s) so user can resubmit"
        end
      else
        emit_form($USER, myrecord, button_help, uimap)
      end
    end
  end
end
