#!/usr/bin/env ruby
PAGETITLE = "Whimsy Member and Officer Surveys" # Wvisible:members
# survey_layout is read from JSON and displayed
# Submissions are tracked by user login, and svn ci into a survey_data JSON
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'wunderbar/markdown'
require 'whimsy/asf'
require 'whimsy/asf/forms'
require 'whimsy/asf/rack'
require 'json'
require 'cgi'

SURVEY = :survey
ERRORS = :errors
PARAMS = :params
CONTACT = :contact
FORM = :form
SDATA = '-data'
DOTJSON = '.json'

# Convenience method to display alerts
def display_alert(lead: 'Error', body: '', type: 'alert-danger')
  _div.alert class: type, role: 'alert' do
    _p.lead lead
    _markdown body
  end
end

# Convenience method to get root dir for surveys
# TODO factor out common survey tools into library, allowing separate members/committers surveys
def get_survey_root(asfsvn = false)
  if asfsvn
    return 'officers_surveys'
  else
    return ASF::SVN.svnpath!('officers','surveys')
  end
end

# Convenience method to sanitize/construct paths to .json
# @param filename to request, either a layout or datafile
# @return sanitized path/filename
def get_survey_path(f)
  filename = f
  filename ||= 'NO_DATAFILE_GIVEN' # For display in errors later
  filename.gsub!(/[^0-9A-Z.-]/i, '_') # Sanitize input (should only be a filename)
  filename << DOTJSON if not filename.end_with?(DOTJSON)
  # test
  begin
    return File.join(ASF::SVN[get_survey_root(true)], filename)
  rescue Exception => _e
    return "ERROR-NO-OFFICERS_SURVEYS-CHECKOUT" # Improve error display in browser
  end
end

# Emit HTML for a survey_layout form, or display any errors in response to a GET
# Currently, user can only submit a survey_data once
# @param hash containing [SURVEY][FORM] => entire survey layout
def display_survey(survey_layout)
  warning = false
  survey_file = get_survey_path(survey_layout[SURVEY][:datafile])
  if survey_layout.has_key?(ERRORS)
    display_alert(lead: 'Error: could not load survey layout!', body: "#{survey_layout[ERRORS]} Contact the survey owner: #{survey_layout[SURVEY][CONTACT]}.")
  elsif File.file?(survey_file)
    survey_data = {}
    begin
      survey_data = JSON.parse(File.read(survey_file), :symbolize_names => true)
      # Check if the user has already submitted this survey
      if survey_data.has_key?($USER.to_sym)
        display_alert(lead: 'Warning: User already submitted survey data!', body: "#{__method__}(#{survey_file}) You appear to have **already submitted** this survey data; you may want to edit the survey.json in SVN, or contact the survey owner: #{survey_layout[SURVEY][CONTACT]}.")
        warning = true
      end
    rescue StandardError => e
      display_alert(lead: 'Error: parsing survey datafile!', body: "**#{__method__}(#{survey_file}) #{e.message}**\n\n    #{e.backtrace[0]}")
      warning = true
    end
  else
    display_alert(lead: 'Warning: could not find survey datafile!', body: "**#{__method__}(#{survey_file})** the data file to store survey answers was not supplied or found; contact the survey owner: #{survey_layout[SURVEY][CONTACT]}.")
    warning = true
  end

  # Emit the survey, or the default one which provides help on the survey tool
  _whimsy_panel("#{survey_layout[SURVEY][FORM][:title]} (user: #{$USER})", style: 'panel-success') do
    _form.form_horizontal method: 'post' do
      survey_layout[SURVEY][FORM][:fields].each do |field|
        _whimsy_field_chooser(field)
      end
      _div.col_sm_offset_3.col_sm_9 do
        _span.help_block id: 'submit_help' do
          _span.text_info survey_layout[SURVEY][FORM][:buttonhelp]
          _span.text_danger 'Warning! Note potential errors above.' if warning
        end
        _input.btn.btn_default type: 'submit', id: 'submit', value: survey_layout[SURVEY][FORM][:buttontext], aria_describedby: 'submit_help'
      end
    end
  end
end

# Validation as needed within the script
def validate_survey(_formdata: {})
  return true # TODO: Futureuse
end

# Handle POST submission (checkout survey data, add user's submission, checkin file)
# @return true if we think it succeeded; false in all other cases
def submit_survey(formdata: {})
  filename = get_survey_path(formdata[:datafile])
  formdata.delete(:datafile) # Remove before generating output
  submission_data = JSON.pretty_generate(formdata) + "\n"
  _div.well do
    _p.lead "Submitting your survey data to: #{filename}"
    _pre "(#{$USER})\n#{submission_data}"
  end

  rc = 999 # Ensure it's a bogus value
  Dir.mktmpdir do |tmpdir|
    ASF::SVN.svn_('checkout',[get_survey_root(), tmpdir],_,{depth: 'files', user: $USER, password: $PASSWORD})

    survey_data = JSON.parse(File.read(filename), :symbolize_names => true)
    # Add user data (may overwrite existing entry!)
    survey_data[$USER] = formdata
    # Sort file (to keep diff clean) and write it back
    survey_data = Hash[survey_data.keys.sort.map {|k| [k, survey_data[k]]}]

    File.write(filename, JSON.pretty_generate(survey_data))
    Dir.chdir tmpdir do
      # rc = ASF::SVN.svn_('commit', filename, _, {msg: "Survey submission (whimsy)", user: $USER, password: $PASSWORD})
    end
  end
  if rc == 0
    return true
  else
    return false
  end
end

DEFAULT_SURVEY = {
  title: 'Apache Whimsy Survey Tool',
  subtitle: 'Survey Help Page',
  contact: 'dev@whimsical.apache.org',
  related: {
    "committers/tools.cgi" => "All Whimsy Committer-wide Tools",
    "https://github.com/apache/whimsy/blob/master/www/" => "See Whimsy Source Code",
    "mailto:dev@whimsical.apache.org?subject=[FEEDBACK] Survey Tool" => "Email Feedback To dev@whimsical"
  },
  helpblock: %q(**If you are reading this**, then there was an error attempting to load your survey's layout - sorry!

This Whimsy Survey tool allows you to define a set of questions in a .json file, and then ask ASF Members or Officers to fill in the survey with a simple URL here.  All submissions are done by an SVN commit with the user's credentials into a survey_data.json file for each survey (answers in a hash associated with ApacheID).

For now, see the code for more help, or contact dev@whimsical for questions on how the tool works.
  ),
  datafile: 'SAMPLE-TBD',
  submitpass: 'This *markdown-able* message would be displayed after a successful svn commit of survey data.',
  submitfail: 'This *markdown-able* message would be displayed after a **FAILED** svn commit of survey data.',
  form: {
    title: 'Survey Help',
    buttonhelp: 'This sample survey won\'t work, but you can still press the button below if you like!',
    buttontext: 'Do Not Press',
    fields: [
    ]
  }
}

# Load survey layout hash from QUERY_STRING ?survey=surveyname
# @return {PARAMS: {}, SURVEY: {}, ERRORS: ""} of form layout data for survey; or a default layout of help with ERRORS also set
# Note: does not validate that the survey has a place to store data; only that the layout exists
def get_survey_layout(query)
  params = {}
  CGI::unescape(query).split('&').each do |keyval|
    k, v = keyval.split('=', 2)
    v && (v.length == 1) ? params[k] = v[0] : params[k] = v
  end
  data = {}
  data[PARAMS] = params
  filename = get_survey_path(params['survey'])
  begin
    data[SURVEY] = JSON.parse(File.read(filename), :symbolize_names => true) # TODO: Security, ensure user should have access
  rescue StandardError => e
    data[ERRORS] = "**ERROR:#{__method__}(#{query}, #{filename}) #{e.message}**\n\n    #{e.backtrace.join("\n    ")}"
  end
  # Fallback if not successfully read, display DEFAULT_SURVEY which shows user help
  if not data.has_key?(SURVEY)
    data[SURVEY] = DEFAULT_SURVEY
    data[ERRORS] = "**Could not read survey layout:** `#{filename}`\n\nPlease check your query string params: #{params}; displaying help form below instead."
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
    _.post? ? title = "#{survey_layout[SURVEY][:title]} (Submission)" : title = survey_layout[SURVEY][:title]
    _whimsy_body(
      title: title,
      subtitle: survey_layout[SURVEY][:subtitle],
      related: survey_layout[SURVEY][:related],
      helpblock: -> {
        _markdown survey_layout[SURVEY][:helpblock]
     }
    ) do
      # Display data to the user, depending if we're GET (a blank survey) or POST (show SVN checkin results)
      if _.post?
        formdata = _whimsy_params2formdata(_.params)
        formdata[:datafile] = survey_layout[SURVEY][:datafile] # Also pass thru datafile from layout
        if validate_survey(formdata: formdata) && submit_survey(formdata: formdata)
          display_alert(lead: 'Survey Submitted', body: survey_layout[SURVEY][:submitpass], type: 'alert-success')
        else
          display_alert(lead: 'Submission Failed', body: survey_layout[SURVEY][:submitfail])
        end
      else # if _.post?
        display_survey(survey_layout)
      end
    end
  end
end

