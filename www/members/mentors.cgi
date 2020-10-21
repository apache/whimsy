#!/usr/bin/env ruby
PAGETITLE = "Available Mentors For New Members" # Wvisible:members
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar/bootstrap'
require 'wunderbar/markdown'
require 'json'

require_relative 'mentor-format'
MENTORS_LIST = 'mentors'
MENTORS_SVN = 'foundation_mentors'

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
def read_mentors
  mentors = {}
  Dir[File.join(ASF::SVN[MENTORS_SVN], '*.json')].sort.each do |file|
    # Skip files with - dashes, they aren't apacheids
    next if file.include?('-')
    read_mentor(file, mentors)
  end
  return mentors
end

# produce HTML
_html do
  _body? do
    uimap = mentors = errors = notavailable = {} # Fill in later in case of errors
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'About This Mentoring Program',
      relatedtitle: 'Other ASF Mentoring Links',
      related: {
        MentorFormat::MENTORS_SVN => 'See Raw Mentors Data',
        '/roster/members' => 'Whimsy All Members Roster',
        '/members/index/' => 'Other Member-Private Tools',
        'https://community.apache.org' => 'Apache Community Development'
      },
      helpblock: -> {
        uimap = MentorFormat::get_uimap(ASF::SVN[MENTORS_SVN])
        mentors = read_mentors
        errors, mentors = mentors.partition{ |k,v| v.has_key?(MentorFormat::ERRORS)}.map(&:to_h)
        notavailable, mentors = mentors.partition{ |k,v| v.has_key?(MentorFormat::NOTAVAILABLE)}.map(&:to_h)
        _p do
          _ 'This page lists experienced ASF Members who have volunteered to mentor newer ASF Members to help them get more involved in governance and operations within the larger Foundation as a whole.'
        end
        _p do
          _ "If you are a newer Member looking for a mentor, please reach out directly to available volunteers below that fit your interests by #{uimap['contact'][0]} and request mentoring.  Not every mentoring pair may be the right fit, so you'll need to decide together if you're a good pair."
          _ 'Remember, this is an informal program run by volunteers, so please be kind - and patient!   Mentors currently listed as available for new mentees:'
        end
        _table do
          _tr do
            _td do
              _a.btn.btn_default.btn_sm (mentors.has_key?($USER) ? 'Edit Your Mentor Record' : 'Volunteer To Mentor'), href: "/members/mentor-update.cgi", role: "button"
            end
            _td do
              _{"&nbsp;"*2}
            end
            _td do
              _ul.list_inline do
                mentors.each do | apacheid, mentor |
                  _li do
                    _a apacheid, href: "##{apacheid}"
                  end
                end
              end
            end
          end
        end
        _p.text_warning 'Reminder: All Mentoring data is private to the ASF; only ASF Members can sign up here as Mentors or Mentees.'
      }
    ) do
      _div.panel_group id: MENTORS_LIST, role: "tablist", aria_multiselectable: "true" do
        mentors.each_with_index do |(apacheid, mentor), n| # TODO Should we randomize the default listing?
          timezone = mentor[MentorFormat::TIMEZONE]
          offset = TZInfo::Timezone.get(timezone).strftime("%:z")
          _whimsy_accordion_item(listid: MENTORS_LIST, itemid: apacheid, itemtitle: "#{mentor[MentorFormat::PUBLICNAME]}  (#{apacheid})  Timezone: #{timezone} (#{offset})  ", n: n, itemclass: 'panel-primary') do
            _table.table.table_hover do
              _tbody do
                mentor.delete(MentorFormat::PUBLICNAME) # So not re-displayed again
                mentor.each do |k, v|
                  _tr do
                    _td!.text_right do
                      _span.text_primary uimap.has_key?(k) ? uimap[k][0] : k
                    end
                    _td!.text_left do
                      v = v.join(', ') if v.kind_of?(Array)
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
                  _ error[MentorFormat::ERRORS]
                end
              end
            end
            _p 'Please work with dev@whimsical to fix these JSON files.'
          end
        end
      end

    end
  end
end