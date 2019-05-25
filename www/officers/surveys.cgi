#!/usr/bin/env ruby
PAGETITLE = "Whimsy Member and Officer Surveys" # Wvisible:members
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'wunderbar/markdown'
require 'whimsy/asf'
require 'whimsy/asf/forms2'
require 'whimsy/asf/rack'
require 'json'
require 'cgi'

FOUNDATION_SVN = ASF::SVN['foundation'] # TODO check pathing
SURVEY = 'survey'
SURVEYS_DIR = 'surveys'
ERRORS = 'errors'
PARAMS = 'params'

# Convenience method to display alerts
def display_alert(lead: 'Error', body: '', type: 'alert-danger')
  _div.alert class: type, role: 'alert' do
    _p.lead lead
    _markdown body
  end
end

# Emit HTML for a survey form, or display any errors
# Currently, user can only submit a survey once
def display_survey(survey_layout)
  if survey_layout.has_key?(ERRORS)
    display_alert(lead: "Unable to read survey layout!", body: "#{survey_layout[ERRORS]}\n\nPlease check your query string params: #{survey_layout[PARAMS]} or check to see if the survey data is valid: #{survey_file}", type: 'alert-warning')
  end
  dataroot = survey_layout['dataroot']
  datafile = survey_layout['datafile']
  survey_file = "#{dataroot} /#{SURVEYS_DIR}/ #{datafile}"
  if dataroot && datafile
    survey_file = File.join(ASF::SVN[survey_layout['dataroot']], SURVEYS_DIR, datafile)
    if File.file?(survey_file)
      # Check if the user has already submitted this survey
      survey_data = {}
      begin
        survey_data = JSON.parse(File.read(survey_file))
        if survey_data.has_key?($USER)
          display_alert(lead: 'User already submitted survey', body: "You appear to have already submitted this survey (#{query}) once; if needed, edit the survey.json in SVN.")
          # return # TODO should we bail or continue?
        end
      rescue StandardError => e
        display_alert(lead: 'Error reading survey data file', body: "**ERROR:#{__method__}(#{query}) #{e.message}**\n\n    #{e.backtrace[0]}")
        # return # TODO should we bail or continue?
      end
    else
      display_alert(lead: "Unable to read survey data!", body: "#{survey_layout[ERRORS]}\n\nPlease check your query string params: #{survey_layout[PARAMS]} or check to see if the survey data is valid: #{survey_file}")
      # return # TODO should we bail or continue?
    end
  else
    display_alert(lead: "Unable to read survey layout!", body: "#{survey_layout[ERRORS]}\n\nPlease check your query string params: #{survey_layout[PARAMS]} or check to see if the survey data is valid: #{survey_file}")
    # return # TODO should we bail or continue?
  end

  # Emit the survey if no errors found
  _whimsy_panel("#{survey_layout[SURVEY]['form']['title']}", style: 'panel-success') do
    _form.form_horizontal method: 'post' do
      survey_layout[SURVEY]['form']['fields'].each do |field|
        _whimsy_field_chooser(field) # DEBUG: How do properly pass this hash thru?
      end
      _div.col_sm_offset_3.col_sm_9 do
        _span.text_info survey_layout[SURVEY]['form']['buttonhelp']
        _br
        _input.btn.btn_default type: 'submit', value: survey_layout[SURVEY]['form']['buttontext']
      end
    end
  end
  
  display_alert(lead: "DEBUG: survey_layout data was", body: survey_layout.inspect, type: 'alert-warning')
end

# Validation as needed within the script
def validate_survey(formdata: {})
  return true # TODO: Futureuse
end

# Handle submission (checkout user's apacheid.json, write form data, checkin file)
# @return true if we think it succeeded; false in all other cases
def submit_survey(formdata: {})
  fn = "#{survey_layout['datafile']}.json".untaint # TODO: check path/file here
  submission_data = JSON.pretty_generate(formdata) + "\n"
  _div.well do
    _p.lead "Submitting your survey data to: #{fn}"
    _pre submission_data
    _p "DEBUG: not sending any data for testing! 20190525-sc DEBUG: need to add to existing file, not overwrite"
  end
  return true # DEBUG: not sending any data for testing! 20190525-sc
  # TODO svn checkout, add data as $USER => {submission_data...}
end

DEFAULT_SURVEY = {
  'title' => 'Apache Whimsy Survey Tool',
  'subtitle' => 'Survey Help Page',
  'related' => {
    "committers/tools.cgi" => "All Whimsy Committer-wide Tools",
    "https://github.com/apache/whimsy/blob/master/www/" => "See Whimsy Source Code",
    "mailto:dev@whimsical.apache.org?subject=[FEEDBACK] Survey Tool" => "Email Feedback To dev@whimsical"
  },
  'helpblock' => %q(The Whimsy Survey tool allows you to use an SVN-backed `survey.json` file to capture survey answers from Apache committers (all answers associated with apacheid and a commit.)
**If you are reading this**, then the survey you attempted to view has not be configured yet - sorry!
For now, see the code for more help, or contact dev@whimsical for questions.
  ),
  'dataroot' => '',
  'datafile' => '',
  'submitpass' => 'This *markdown-able* message would be displayed after a successful svn commit of survey data.',
  'submitfail' => 'This *markdown-able* message would be displayed after a **FAILED** svn commit of survey data.',
  'form' => {
    'title' => 'Survey Form Title',
    'buttonhelp' => 'This sample survey won\'t work, but you can still press Submit below!',
    'buttontext' => 'Submit',
    'fields' => [
      {
        'name' => 'field1',
        'type' => 'text',
        'label' => 'This field is:',
        'helptext' => 'This text would explain the field1 (optional)'
      },
      {
        'name' => 'field2',
        'type' => 'text',
        'rows' => '3',
        'label' => 'This is multiline:',
        'helptext' => 'This text would explain the field2 (optional)'
      }
    ]
  }
}
# Return survey layout hash from QUERY_STRING
# @return {} of form layout data for survey; or a default layout of help
# Note: does not validate that the survey has a place to store data; only that the layout exists
def get_survey_layout(query)
  params = {}
  CGI::unescape(query).split('&').each do |keyval|
    k, v = keyval.split('=', 2)
    v && (v.length == 1) ? params[k] = v[0] : params[k] = v
  end
  data = {}
  data[PARAMS] = params
  begin
    data[SURVEY] = JSON.parse(File.read(File.join(FOUNDATION_SVN, SURVEYS_DIR, "#{params[SURVEY]}.json").untaint)) # TODO: Security, ensure user should have access
  rescue StandardError => e
    data[ERRORS] = "**ERROR:#{__method__}(#{query}) #{e.message}**\n\n    #{e.backtrace.join("\n    ")}"
  end
  # Fallback if not successfully read, so we can display something (even if it won't work to submit)
  if not data.has_key?(SURVEY)
    data[SURVEY] = DEFAULT_SURVEY
  end
  return data
end

# produce HTML
_html do
  _style :system
  _style %{
    .transcript {margin: 0 16px}
    .transcript pre {border: none; line-height: 0}
  }
  _body? do
    query_string = ENV['QUERY_STRING']
    survey_layout = get_survey_layout(query_string)
    _whimsy_body(
      title: survey_layout[SURVEY]['title'],
      subtitle: survey_layout[SURVEY]['subtitle'],
      related: survey_layout[SURVEY]['related'],
      helpblock: -> {
        _markdown survey_layout[SURVEY]['helpblock']
     }
    ) do
      # Display data to the user, depending if we're GET (a blank survey) or POST (show SVN checkin results)
      if _.post?
        formdata = _whimsy_params2formdata(_.params)
        if validate_survey(formdata: formdata) && submit_survey(formdata: formdata)
            display_alert(lead: 'Survey Submitted', body: survey_layout[SURVEY]['submitpass'], type: 'alert-success')
          else
            display_alert(lead: 'Submission Failed', body: survey_layout[SURVEY]['submitfail'])
        end
      else # if _.post?
        display_survey(survey_layout)
      end
    end
  end
end
