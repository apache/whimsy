#!/usr/bin/env ruby
PAGETITLE = "Review existing Board statements" # Wvisible:meeting
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
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
      statements = ASF::MemberFiles.board_all
      statements.each do |availid, shash|
        _div id: availid
        _whimsy_panel("Director Nominee: #{shash.fetch('Public Name', '')} (#{availid})", style: 'panel-default') do
          _p do
            _strong "Director's Own Statement (once present)"
            _br
            _ shash.fetch('candidate_statement', '')
          end
          _p do
            _strong "Nominated By: #{shash['nombycn']} (#{shash['nombyeavailid']})"
            _br
            _ "Testing: Seconded by = #{shash['Seconded by']}"
            _ 'Nominator Statment(s):'
            _br
            _ shash.fetch('Nomination Statement', '')
          end
        end
      end
    end
  end
end
