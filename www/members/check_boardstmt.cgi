#!/usr/bin/env ruby
PAGETITLE = "Review existing Board statements" # Wvisible:meeting
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'whimsy/asf/forms'
require 'whimsy/asf/member-files'
require 'whimsy/asf/meeting-util'

_html do
  _body? do
    latest_meeting_dir = ASF::MeetingUtil.latest_meeting_dir
    timelines = ASF::MeetingUtil.get_timeline(latest_meeting_dir)
    _whimsy_body(
      title: PAGETITLE,
      related: {
        'meeting.cgi' => 'Member Meeting FAQ and info',
        'nominate_board.cgi' => 'Nominate someone for the Board',
        'check_membernoms.cgi' => 'Cross-check existing New Member nominations',
        ASF::SVN.svnpath!('Meetings') => 'Official Meeting Agenda Directory'
      },
      helpblock: -> {
        _b "For: #{timelines['meeting_type']} Meeting on: #{timelines['meeting_iso']}"
        _ 'This script displays a list of currently nominated directors and both statements from the Nominator/seconds, and (when present) Candidate statements from the nominees themselves.'
        _br
        _ 'IMPORTANT: many director candidates may not add statements until near the nomination close deadline; this is just a preview!'
        _br
        _ 'This only works in the period shortly before or after a Members meeting!'
      }
    ) do
      _h2 id: 'board-statement-list' do
        _ 'All Board Nominations and Candidate Statements'
      end
      statements = ASF::MemberFiles.board_all
      statements.each do |availid, shash|
        listid = availid
        public_name = shash.fetch('Public Name', availid) # Fallback if missing
        _div.panel.panel_primary id: listid do
          _div.panel_heading do
            _h3!.panel_title do
              _! 'Nominee for Director: '
              _a! "#{public_name} (#{availid})", href: "/roster/committer/#{availid}"
            end
          end
          _div.panel_body do
            _div.panel_group id: listid, role: 'tablist', aria_multiselectable: 'true' do
              _whimsy_accordion_item(listid: listid, itemid: "#{availid}-nomination", itemtitle: "Nominated by: #{shash['nombycn']}", n: 1, itemclass: 'panel-info') do
                _p do
                  _strong "Nominated By: #{shash['nombycn']} (#{shash['nombyeavailid']})"
                  _br
                  _ "Seconded by: #{shash['Seconded by'].join(', ')}"
                  _br
                  _ "Nomination and Seconds Statements:"
                end
                _p do
                  allnoms = shash.fetch('Nomination Statement', '(no statement entered)')
                  allnoms.split('\n') do |l| # FIXME: add styles to key lines or (availids)
                    _! l
                    _br
                  end
                end
              end
              _whimsy_accordion_item(listid: listid, itemid: "#{availid}-statement", itemtitle: "Candidate Statement for (#{availid})", n: 2, itemclass: 'panel-primary') do
                _p do
                   # FIXME: display message for blank/one line or when DECLINE
                   candidate_stmt = shash.fetch('candidate_statement', '') # See also lib/whimsy/asf/member-files.rb::board_statements
                   candidate_stmt.each do |l| # TODO: consider adding styles or markdown processing
                     _! l
                     _br
                   end
                end
              end
            end
          end
        end
      end
    end
  end
end
