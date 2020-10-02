#!/usr/bin/env ruby
PAGETITLE = "Missing Board Reports" # Wvisible:board

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'whimsy/asf/agenda'

RECORDS = 'http://www.apache.org/foundation/records/minutes/'


# Produce HTML
_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        "/board/agenda" => "Current Month Board Agenda",
        "/board/minutes" => "Past Minutes, Categorized",
        "https://www.apache.org/foundation/board/calendar.html" => "Past Minutes, Dated",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code"
      },
      helpblock: -> {
        _p %{
          This counts the number of expected reports to the board that were not timely submitted each month.
          There are a variety of reasons this happens; often projects ask to report a month late if the chair is unavailable.
          Note that the missing number for the current month is as of now; some projects report only a few days before the meeting.
        }
      }
    ) do
      _h1 'Missing Board Reports by Month'
      Dir.chdir ASF::SVN['foundation_board']
      agendas = Dir['**/board_agenda_*'].sort_by {|name| File.basename(name)}[-12..-1]
      _table.table.table_hover.table_striped do
        _thead_ do
          _tr do
            _th.col_md_1 '# Reports'
            _th.col_md_1 '# Missing'
            _th 'Board Minutes or Agenda'
          end
        end
        _tbody do
          agendas.reverse.each do |agenda|
            parsed = ASF::Board::Agenda.parse(File.read(agenda), true)
            _tr_ do
              _td parsed.count, align: 'right'
              _td parsed.count {|report| report["missing"]}, align: 'right'
              _td do
                if agenda.include? 'archived'
                  year = agenda[/\d+/]
                  minutes = File.basename(agenda).sub('agenda', 'minutes')
                  _a File.basename(agenda), href: "#{RECORDS}/#{year}/#{minutes}"
                else
                  date = agenda[/\d+_\d+_\d+/].gsub('_', '-')
                  _a File.basename(agenda), href: "agenda/#{date}/"
                end
              end
            end
          end
        end
      end
    end
  end
end

