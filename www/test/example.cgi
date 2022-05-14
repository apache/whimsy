#!/usr/bin/env ruby
PAGETITLE = "Example Whimsy Script With Styles" # Wvisible:tools
# Note: PAGETITLE must be double quoted

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'json'
require 'yaml'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'wunderbar/markdown'
require 'whimsy/asf'
require 'whimsy/asf/forms'
require 'whimsy/public'

# Get data from live whimsy.a.o/public directory
def get_public_data()
  return Public.getJSON('public_ldap_authgroups.json')
end

# Get data from a Subversion directory
# See /repository.yml for list of auto-updated dirs
def get_svn_data()
  dir = ASF::SVN['comdevtalks']
  filename = 'README.yaml'
  data = YAML.safe_load(File.read(File.join(dir, filename)))
  return data['title']
end

# Gather some data beforehand, if you like, but:
# Note runtime errors here just write to the log, not to user's browser
talktitle = get_svn_data()

# Example of handling POST forms cleanly
def emit_form(title, prev_data)
  _whimsy_panel(title, style: 'panel-success') do
    _form.form_horizontal method: 'post' do
      _div.form_group do
        _label.col_sm_offset_3.col_sm_9.strong.text_left 'Example Form Section'
      end
      field = 'text1'
      _whimsy_forms_input(label: 'Example Text Field', name: field, id: field,
        value: prev_data[field], helptext: 'Enter some text, keep it polite!'
      )
      field = 'listbox'
      _whimsy_forms_select(label: 'Select Some Values', name: field,
        multiple: true, values: prev_data[field],
        options: ['another value', 'yet another value'],
        icon: 'glyphicon-time', iconlabel: 'clock',
        helptext: 'Select as many values as ya like!'
      )
      field = 'text2'
      _whimsy_forms_input(label: 'Another Text Field', name: field, id: field,
        value: prev_data[field], helptext: 'Pretty boring form example, huh?'
      )
      _div.col_sm_offset_3.col_sm_9 do
        _input.btn.btn_default type: 'submit', value: 'PUSH ME!'
      end
    end
  end
end

# Validation as needed within the script
def validate_form(formdata: {})
  return true # TODO: Futureuse
end

# Handle submission (checkout user's apacheid.json, write form data, checkin file)
# @return true if we think it succeeded; false in all other cases
def process_form(formdata: {})
  # Example that uses SVN to update an existing file: members/mentor-update.cgi
  _p class: 'system' do
    _ 'If this were a real process_form() it would do something with your data:'
    _br
    formdata.each do |k,v|
      _ "#{k} = #{v.inspect}"
      _br
    end
  end
  return true
end

# Produce HTML
_html do
  _body? do # The ? traps errors inside this block
    _whimsy_body( # This emits the entire page shell: header, navbar, basic styles, footer
      title: PAGETITLE,
      subtitle: 'About This Example Script',
      relatedtitle: 'More Useful Links',
      related: {
        "/committers/tools" => "Whimsy Tool Listing",
        "https://incubator.apache.org/images/incubator_feather_egg_logo_sm.png" => "Incubator Logo, to show that graphics can appear",
        "https://community.apache.org/" => "Get Community Help",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code"
      },
      helpblock: -> {
        _p "This www/test/example.cgi script shows a canonical way to write a simple whimsy tool that processes data and then displays it."
        _p %{
          This helpblock appears at top left, and should explain to an end user what this script does for the user and why they might be interested.
          Any related whimsy or other (projects.a.o, etc.) links should be in the related: listing on the top right to help users find other useful things.
          This provides a consistent user experience.
        }
        _p "You can output data previously processed as well like: #{talktitle}"
        _ul.list_inline do
          _li do
            _a 'example-table', href: '#example-table'
          end
          _li do
            _a 'example-accordion', href: '#example-accordion'
          end
          _li do
            _a 'example-form', href: '#example-form'
          end
        end
      },
      breadcrumbs: {
        dataflow: '/test/dataflow.cgi',
        testscript: '/test/example.cgi'
      }
    ) do
      # IF YOUR SCRIPT EMITS A LARGE TABLE
      _div id: 'example-table' do
        _whimsy_panel_table(
          title: "Data Table H2 Title Goes Here",
          helpblock: -> {
            _p "If your script displays a sizeable table(s) of data, then use this area to provide a Key: to the data."
          }
        ) do
          # Gather or process your data **here**, so if an error is raised, the _body?
          #   scope will trap it - and will then display the above help information
          #   to the user before emitting a polite error traceback.
          datums = {'one' => 1, 'two' => 2 }
          _table.table.table_hover.table_striped do
            _thead_ do
              _tr do
                _th 'Row Number'
                _th 'Column Two'
              end
              _tbody do
                datums.each do | key, val |
                  _tr_ do
                    _td do
                      _ key
                    end
                    _td do
                      _ val
                    end
                  end
                end
              end
            end
          end
        end
      end

      # IF YOUR SCRIPT ONLY EMITS SIMPLE DATA
      _h2 "Simple Data Can Just Use A List"
      _ul do
        [1,2,3].each do |row|
          _li "This is row number #{row}."
        end
      end

      # NIFTY ACCORDION EXPAND-O LISTING: the _whimsy_accordion_item does most of the work
      _h2 id: 'example-accordion' do
        _ 'Lists of Complex Data Can Use An Accordion'
      end
      accordionid = 'accordion'
      officers = get_public_data()
      _div.panel_group id: accordionid, role: 'tablist', aria_multiselectable: 'true' do
        officers['auth'].each_with_index do |(listname, rosters), n|
          _whimsy_accordion_item(listid: accordionid, itemid: listname, itemtitle: listname, n: n, itemclass: 'panel-primary') do
            _ul do
              rosters['roster'].each do |usr|
                _li usr
              end
            end
          end
        end
      end

      # IF YOU WANT TO DO WORK BASED ON ?QUERY=value
      query = CGI::parse(ENV['QUERY_STRING'])
      if query.has_key?('value')
        _p "Query Value Passed: #{query['value']}" # Will be array
      else
        val = Array(query['query']).last
        _p "Value Query Passed: #{query['query']}"
        _p query.inspect
      end

      # IF YOU WANT TO DISPLAY A FORM and handle the POST
      _div id: 'example-form' do
        if _.post?
          # Use magic _. callouts to CGI class to gather POST data into submission hash
          submission = {}
          keyz = _.keys
          keyz.each do |k|
            submission[k] = _.params[k] # Always as ['val'] or ['one', 'two', ...]
          end
          if validate_form(formdata: submission)
            if process_form(formdata: submission)
              _p.lead "Thanks for Submitting This Form!"
              _p do
                _ "The process_form method would have done any processing needed with the data, after calling validate_data."
              end
            else
              _div.alert.alert_warning role: 'alert' do
                _p "SORRY! Your submitted form data failed process_form, please try again."
              end
            end
          else
            _div.alert.alert_danger role: 'alert' do
              _p "SORRY! Your submitted form data failed validate_form, please try again."
            end
          end
        else # if _.post?
          emit_form('Form Title Here', officers)
        end
      end
    end
  end
end
