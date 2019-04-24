#!/usr/bin/env ruby
PAGETITLE = "Available Mentors For New Members" # Wvisible:members
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar/bootstrap'
require 'wunderbar/markdown'
require 'json'

ROSTER = 'https://whimsy.apache.org/roster/committer/'
MENTORS_SVN = 'https://svn.apache.org/repos/private/foundation/mentors/'
PUBLICNAME = 'publicname'
NOTAVAILABLE = 'notavailable'
ERRORS = 'errors'
UI_MAP = {
  'timezone' => 'Timezone',
  'availability' => 'Preferred Times To Contact',
  'contact' => 'Preferred Contact Method',
  'prefers' => 'Preferred Communication Modes',
  'available' => 'Seeking Mentees?',
  'mentoring' => 'Already Mentoring',
  'experience' => 'Areas Of Experience',
  'languages' => 'Languages Spoken',
  'pronouns' => 'Personal Pronouns',
  'aboutme' => 'About Me', 
  'homepage' => 'Personal Homepage'
}

# Read apacheid.json and add data to mentors hash (side effect)
# mentors[id][ERRORS] = "If errors rescued during read/find in ASF::Person"
def read_mentor(file, mentors)
  id = File.basename(file).split('.')[0]
  member = ASF::Person[id] # We want to return nil if id not found
  if member
    begin
      mentors[id] = JSON.parse(File.read(file))
      mentors[id][PUBLICNAME] = member.public_name()
    rescue StandardError => e
      mentors[id] = { ERRORS => "ERROR:read_mentor() #{e.message} #{e.backtrace[0]}"}
    end
  else
    mentors[id] = { ERRORS => "ERROR:ASF::Person.find(#{id}) returned nil"}
  end
end

# Read *.json from directory of mentor files
# @return hash of mentors by apacheid
def read_mentors(path)
  mentors = {}
  Dir[File.join(path, '*.json')].sort.each do |file|
    file.untaint
    read_mentor(file, mentors)
  end
  return mentors
end

# produce HTML
_html do
  _body? do
    mentors = read_mentors(ASF::SVN['foundation_mentors'])
    errors, mentors = mentors.partition{ |k,v| v.has_key?(ERRORS)}.map(&:to_h)
    notavailable, mentors = mentors.partition{ |k,v| v.has_key?(NOTAVAILABLE)}.map(&:to_h)
    _whimsy_body(
      title: PAGETITLE,
      related: {
        MENTORS_SVN => 'See Mentors Data',
        '/roster/members' => 'Whimsy All Members Roster',
        '/members/index/' => 'Other Member-Private Tools',
        'https://community.apache.org' => 'Apache Community Development'
      },
      helpblock: -> {
        _p do
          _ 'This page lists experienced ASF Members who have volunteered to mentor newer ASF Members to help them get more involved in Foundation governance and operations.'
          _br
          _ "If you are a newer Member looking for a mentor, please reach out directly to available volunteers below by #{UI_MAP['contact']}. "
          _ 'Remember, this is an informal program run by volunteers, so please be kind - and patient!  Mentors currently listed:'
        end 
        _ul.list_inline do
          mentors.each do | apacheid, mentor |
            _li do
              _a apacheid, href: "##{apacheid}"
            end
          end
        end
        if mentors.has_key?($USER) # TODO make a whimsy UI for this
          _a.btn.btn_default.btn_sm 'Edit Your Mentor Record', href: "#{File.join(MENTORS_SVN, $USER + '.json')}", role: "button"
        else
          _a.btn.btn_default.btn_sm 'Volunteer To Mentor', href: "#{File.join(MENTORS_SVN, 'README')}", role: "button"
        end
      }
      ) do
      mentors.each do | apacheid, mentor |
        _div id: apacheid do
          _whimsy_panel_table(title: "#{mentor[PUBLICNAME]} (#{apacheid})") do
            mentor.delete(PUBLICNAME)
            _table.table.table_hover do
              _tbody do
                mentor.each do |k, v|
                  _tr do
                    _td!.text_right do
                      _span.text_primary UI_MAP.has_key?(k) ? "#{UI_MAP[k]}" : "#{k}"
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
                    _a "#{ROSTER}#{apacheid}", href: "#{ROSTER}#{apacheid}"
                  end
                end
              end
            end
          end
        end
      end
      
      if not errors.empty?
        _div id: ERRORS do
          _whimsy_panel("Mentor JSON Files With Errors", style: 'panel-danger') do
            _ul do
              errors.each do |apacheid, error |
                _li do
                  _code apacheid
                  _ "#{error[ERRORS]}"
                end
              end
            end
          end
        end
      end
      
      if not notavailable.empty?
        _div id: NOTAVAILABLE do
          _p! do
            _! 'Volunteer mentors who are '
            _strong! 'not'
            _! ' currently available for new mentees: '
            notavailable.each do |apacheid, n |
              _ "#{n[PUBLICNAME]}, "
            end
          end
        end
      end
    end
  end
end