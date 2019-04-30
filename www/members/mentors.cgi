#!/usr/bin/env ruby
PAGETITLE = "Available Mentors For New Members" # Wvisible:members
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar/bootstrap'
require 'wunderbar/markdown'
require 'json'

require_relative 'mentor-format'
MENTORS_LIST = 'mentors'

# Read apacheid.json and add data to mentors hash (side effect)
# mentors[id][ERRORS] = "If errors rescued during read/find in ASF::Person"
def read_mentor(file, mentors)
  id = File.basename(file).split('.')[0]
  member = ASF::Person[id] # We want to return nil if id not found
  if member
    begin
      mentors[id] = JSON.parse(File.read(file))
      mentors[id][MentorFormat::PUBLICNAME] = member.public_name()
    rescue StandardError => e
      mentors[id] = { MentorFormat::ERRORS => "ERROR:read_mentor() #{e.message} #{e.backtrace[0]} from #{file}"}
    end
  else
    mentors[id] = { MentorFormat::ERRORS => "ERROR:ASF::Person.find(#{id}) returned nil from #{file}"}
  end
end

# Read *.json from directory of mentor files
# @return hash of mentors by apacheid
def read_mentors(path)
  mentors = {}
  Dir[File.join(path, '*.json')].sort.each do |file|
    # Skip files with - dashes, they aren't apacheids
    next if file.include?('-')
    file.untaint
    read_mentor(file, mentors)
  end
  return mentors
end

# produce HTML
_html do
  _body? do
    uimap = MentorFormat::get_uimap(ASF::SVN['foundation_mentors'])
    mentors = read_mentors(ASF::SVN['foundation_mentors'])
    errors, mentors = mentors.partition{ |k,v| v.has_key?(MentorFormat::ERRORS)}.map(&:to_h)
    notavailable, mentors = mentors.partition{ |k,v| v.has_key?(MentorFormat::NOTAVAILABLE)}.map(&:to_h)
    _whimsy_body(
      title: PAGETITLE,
      related: {
        MentorFormat::MENTORS_SVN => 'See Mentors Data',
        '/roster/members' => 'Whimsy All Members Roster',
        '/members/index/' => 'Other Member-Private Tools',
        'https://community.apache.org' => 'Apache Community Development'
      },
      helpblock: -> {
        _p do
          _ 'This page lists experienced ASF Members who have volunteered to mentor newer ASF Members to help them get more involved in Foundation governance and operations.'
          _br
          _ "If you are a newer Member looking for a mentor, please reach out directly to available volunteers below by #{uimap['contact'][0]}. "
          _ 'Remember, this is an informal program run by volunteers, so please be kind - and patient!  Mentors currently listed:'
        end 
        _ul.list_inline do
          mentors.each do | apacheid, mentor |
            _li do
              _a apacheid, href: "##{apacheid}"
            end
          end
        end
        _a.btn.btn_default.btn_sm (mentors.has_key?($USER) ? 'Edit Your Mentor Record' : 'Volunteer To Mentor'), href: "/members/mentor-update.cgi", role: "button"
      }
    ) do
      _div.panel_group id: MENTORS_LIST, role: "tablist", aria_multiselectable: "true" do
        mentors.each_with_index do |(apacheid, mentor), n|
          _div!.panel.panel_default  id: apacheid do
            _div!.panel_heading role: "tab", id: "#{MENTORS_LIST}h#{n}" do
              _h4!.panel_title do
                _a!.collapsed role: "button", data_toggle: "collapse",  aria_expanded: "false", data_parent: "##{MENTORS_LIST}", href: "##{MENTORS_LIST}c#{n}", aria_controls: "#{MENTORS_LIST}c#{n}" do
                  _ "#{mentor[MentorFormat::PUBLICNAME]}  (#{apacheid})  Timezone: #{mentor[MentorFormat::TIMEZONE]}  "
                  _span.glyphicon class: "glyphicon-chevron-down"
                  mentor.delete(MentorFormat::PUBLICNAME) # So not re-displayed below
                end
              end
            end
            _div!.panel_collapse.collapse id: "#{MENTORS_LIST}c#{n}", role: "tabpanel", aria_labelledby: "#{MENTORS_LIST}h#{n}" do
              _div!.panel_body do
                _table.table.table_hover do
                  _tbody do
                    mentor.each do |k, v|
                      _tr do
                        _td!.text_right do
                          _span.text_primary uimap.has_key?(k) ? "#{uimap[k][0]}" : "#{k}"
                        end
                        _td!.text_left do
                          _markdown v
                        end
                      end
                    end
                    _tr do
                      _td!.text_right do
                        _ 'ASF Projects/Podlings Involved In'
                      end
                      _td!.text_left do
                        # TODO: instead of link to roster, this could read and display here
                        _a "#{MentorFormat::ROSTER}#{apacheid}", href: "#{MentorFormat::ROSTER}#{apacheid}"
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      if not notavailable.empty?
        _div id: MentorFormat::NOTAVAILABLE do
          _p! do
            _! 'Volunteer mentors who are '
            _strong! 'not'
            _! ' currently available for new mentees: '
            notavailable.each do |apacheid, n |
              _ "#{n[MentorFormat::PUBLICNAME]}, "
            end
          end
        end
      end

      if not errors.empty?
        _div id: MentorFormat::ERRORS do
          _whimsy_panel("Mentor JSON Files With Errors", style: 'panel-danger') do
            _ul do
              errors.each do |apacheid, error |
                _li do
                  _code "#{apacheid}.json"
                  _ "#{error[MentorFormat::ERRORS]}"
                end
              end
            end
          end
        end
      end

    end
  end
end