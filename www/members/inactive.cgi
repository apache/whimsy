#!/usr/bin/ruby1.9.1
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

require 'whimsy/asf'
require 'wunderbar/bootstrap'
require 'date'
require 'json'

# locate and read the attendance file
MEETINGS = ASF::SVN['private/foundation/Meetings']
attendance = JSON.parse(IO.read("#{MEETINGS}/attendance.json"))

# determine user's name as found in members.txt
name = ASF::Member.find_text_by_id($USER).to_s.split("\n").first
matrix = attendance['matrix'][name]

# produce HTML
_html do
  _h1 'Attendance history'

  if not name

    _p.alert.alert_danger "#{$USER} not found in members.txt"

  elsif not matrix

    _p.alert.alert_danger "#{name} not found in attendance matrix"

  else

    count = 0
    _table.table.table_sm style: 'margin: 0 24px; width: auto' do
      _thead do
        _tr do
          _th 'Date'
          _th 'Status'
        end
      end

      matrix.sort.reverse.each do |date, status|
        next if status == ' '

        color = 'bg-danger'
        color = 'bg-warning' if %w(e).include? status
        color = 'bg-success' if %w(A V P).include? status

        _tr_ class: color do
          _td date

          case status
          when 'A'
            _td 'Attended'
          when 'V'
            _td 'Voted but did not attend'
          when 'P'
            _td 'Attended via proxy'
          when '-'
            _td 'Did not attend'
          when 'e' 
            _td 'Went emeritus'
          else
            _td status
          end
        end
      end
    end
  end
end
