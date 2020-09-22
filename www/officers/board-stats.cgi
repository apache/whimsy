#!/usr/bin/env ruby
PAGETITLE = "Board Meeting Statistics since 2007" # Wvisible:meeting
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'whimsy/asf/agenda'
require 'whimsy/public'
require 'wunderbar/bootstrap'
require 'json'
require 'set'

BOARD = ASF::SVN['foundation_board']
REPO = ASF::SVN.svnurl('foundation_board')

# Hash keys returned by summarize
ERRORS = 'errors'
PEOPLE = 'people'
OFFICERS = 'officers'
PMCS = 'pmcs'
ACTIONS = 'actions'

# produce HTML
_html do
  _whimsy_body(
    title: PAGETITLE,
    related: {
      '/board/minutes' => 'Monthly Board Meeting Minutes (categorized)',
      'https://www.apache.org/foundation/board/calendar.html' => 'Monthly Board Meeting Minutes (by date)',
      '/roster/group/board' => 'Current List of Directors'
    },
    helpblock: -> {
      _ 'This summarizes statistics about monthly board meetings since 2007.  Before 2007, the data collected below isn\'t easily parseable or wasn\'t consistently stored in meeting agendas.'
    }
    ) do
    datums = JSON.parse(File.read(File.join(BOARD, 'scripts', 'meeting-summary.json')))
    _whimsy_panel_table(
      title: "Monthly Board Meeting Statistics",
      helpblock: -> {
        _p do
          _ "Some months' minutes are skipped because data can't be easily parsed ("
          _a! "see below for list", href: "#skips"
          _ ").  Most data is generated from public board meeting minutes, however some is "
          _strong.text_warning "PRIVATE DATA: "
          _ "The numbers of Average Preapprovals and Report Comments Length are private, and must not be shared outside the Membership."
        end
        _p "Note: the text format of board minutes changed over time.  Summaries before 2008 may not accurately reflect actual meeting actions due to parsing issues."
      }
      ) do
      _table.table.table_hover.table_striped do
        _thead_ do
          _tr do
            _th 'Date'
            _th '# Directors Attend'
            _th '# Officers/Guests Attend'
            _th '# Special Orders'
            _th '# Officer Reports'
            _th '# PMC Reports'
            _th 'Average Report Text Length'
            _th.text_warning 'Average Report Comments Length'
            _th.text_warning 'Average # Preapprovals'
            _th 'Discussion Items Section Text Length'
          end
        end
        _tbody do
          datums.select{ |k,v| !'stats'.eql?(k) && v.has_key?(PEOPLE) }.each.reverse_each do | month, agenda |
            directors, others = agenda[PEOPLE].select{ |id, data| data['attending'] }.partition{ |id, data| 'director'.eql?(data['role']) }
            _tr_ do
              _td do
                file = month + '.txt'
                if not File.exist? File.join(BOARD, file)
                  file = File.join('archived_agendas', file)
                end

                _a month.sub('board_agenda_', '').gsub('_', '-'),
                  href: File.join(REPO, file)
              end
              _td.text_center do
                dct = directors.length
                if 9 == dct
                  _ dct
                else
                  _span.text_warning dct
                end
              end
              _td.text_center do
                _ others.length
              end
              _td.text_center do
                _ agenda['stats']['specialorders']
              end
              _td.text_center do
                _ agenda[OFFICERS].length
              end
              _td.text_center do
                _ agenda[PMCS].length
              end
              _td.text_center do
                _ agenda['stats']['avgreportlen'].round(0) if agenda['stats'].has_key?('avgreportlen')
              end
              _td.text_center do
                _ agenda['stats']['avgcommentlen'].round(0) if agenda['stats'].has_key?('avgcommentlen')
              end
              _td.text_center do
                _ agenda['stats']['avgapprovals'].round(1) if agenda['stats'].has_key?('avgapprovals')
              end
              _td.text_center do
                _ agenda['stats']['discusstextlen']
              end
            end
          end
        end
      end
    end
    _h3.skips! 'Note: Some Months Are Skipped'
    _p "Some month's agendas aren't easily parsed due to different formatting, and are skipped (i.e. not counted here). Current skip list:"
    _ul do
      datums.select{ |k,v| v.is_a?(Hash) && v.has_key?(ERRORS) }.each do |month, agenda|
        _li do
          _a href: File.join(REPO, 'archived_agendas', "#{month}.txt") do
            _span.text_warning month
            _ " - #{agenda[ERRORS].partition(')').last}"
          end
        end
      end
    end

  end
end

