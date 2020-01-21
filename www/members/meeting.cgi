#!/usr/bin/env ruby
PAGETITLE = "Member's Meeting Information" # Wvisible:meeting
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar/bootstrap'
require 'date'
require 'json'
require 'wunderbar/jquery/stupidtable'
require_relative 'meeting-util'

# Output action links for meeting records, depending on if current or past
def emit_meeting(cur_mtg_dir, meeting, active)
  _div id: "meeting-#{meeting}"
  _whimsy_panel("All Meeting Details for #{meeting}", style: 'panel-info') do 
    num_members, quorum_need, num_proxies, attend_irc = MeetingUtil.calculate_quorum(cur_mtg_dir)
    if num_members
      if active
        _p do
          _ 'Currently, we will need '
          _span.text_primary "#{attend_irc}" 
          _ " Members attending the first half of the meeting on Tuesday and respond to Roll Call to reach quorum and continue the meeting."
          _ " Calculation: Total voting members: #{num_members}, with one third for quorum: #{quorum_need}, minus previously submitted proxies: #{num_proxies}"
        end
      else
        _p do
          _ 'At the time of this past meeting, we had:'
          _ul do
            _li "#{num_members} eligible voting Members,"
            _li "#{quorum_need} needed for quorum (one third),"
            _li "#{num_proxies} proxy assignments available for the meeting,"
            _li "And hoped that at least #{attend_irc} would attend the start of meeting."
          end
          attendees = File.readlines(File.join(cur_mtg_dir, 'attend'))
          _ "By the end of the meeting, we had a total of #{attendees.count} Members participating (either via attending IRC, sending a proxy, or voting via email)"
        end
      end
    end
    _p active ? "Live links to the upcoming meeting records/how-tos below." : "These are historical links to the past meeting's record."
    _ul do
      MeetingUtil::MEETING_FILES.each do |f, desc|
        _li do # Note: cheezy path detection within MEETING_FILES
          _a desc, href: f.include?('/') ? f : File.join(cur_mtg_dir, f)
        end
      end
    end
  end
end

# produce HTML
_html do
  _body? do
    MEETINGS = ASF::SVN['Meetings']
    cur_mtg_dir = MeetingUtil.get_latest(MEETINGS).untaint
    meeting = File.basename(cur_mtg_dir)
    mtg_date = Date.parse(meeting)
    today = Date.today.strftime('%Y%m%d')
    
    ROSTER = "/roster/committer"
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Meeting How-Tos',
      relatedtitle: 'More About Meetings',
      related: {
        'https://www.apache.org/foundation/governance/meetings' => 'How Meetings & Voting Works',
        '/members/proxy' => 'Assign A Proxy For Next Meeting',
        '/members/non-participants' => 'Members Not Participating',
        '/members/inactive' => 'Inactive Member Feedback Form',
        MeetingUtil::RECORDS => 'Official Past Meeting Records'
      },
      helpblock: -> {
        if today > meeting
          _p do
            _ %{
              The last Annual Member's Meeting was held #{mtg_date.strftime('%A, %d %B %Y')}.  Expect the 
              next Member's meeting to be scheduled between 12 - 13 months after 
              the previous meeting, as per 
            }
            _a 'https://www.apache.org/foundation/bylaws.html#3.2', 'the bylaws.'
            _ 'Stay tuned for a NOTICE email on members@ announcing the next meeting.  The below information is about the '
            _span.text_warning 'LAST'
            _ " Member's meeting."
          end
        else
          _p do
            _ "The next Member's Meeting will start on #{mtg_date.strftime('%A, %d %B %Y')}, as an online meeting on IRC, and will finish up two days later after voting via email is held."
            _ 'For more details, read on below, or see the links to the right.'
          end
        end
      }
    ) do
      help, copypasta = MeetingUtil.is_user_proxied(cur_mtg_dir, $USER)
      attendance = JSON.parse(IO.read(File.join(MEETINGS, 'attendance.json')))
      _whimsy_panel("Your Details For Meeting #{meeting}", style: 'panel-primary') do
        # TODO: remind member to check their committer.:email_forward address is correct (where ballots are sent)
        _p do
          if help
            _p help
            if copypasta
              _ul.bg_success do
                copypasta.each do |copyline|
                  _pre copyline
                end
              end
            end
          else
            _ 'You are neither a proxy for anyone else, nor do you appear to have assigned a proxy for your attendance.'
          end
        end
      end
      
      emit_meeting(cur_mtg_dir, meeting, meeting >= today)
      
      _whimsy_panel("Member Meeting History", style: 'panel-info') do
        all_mtg = Dir[File.join(MEETINGS, '19*'), File.join(MEETINGS, '2*')].sort
        _p do
          _ %{ 
            The ASF has held #{all_mtg.count} Member's meetings in our 
            history. Some were Annual meetings, were we elect a new board; 
            a handful were Special mid-year meetings where we mostly just 
            elected new Members.
          }
          _ ' Remember, member meeting minutes are '
          _span.text_warning 'private'
          _ ' to the ASF. You can see your '
          _a 'your own attendance history at meetings.', href: '/members/inactive#attendance'
          _ul do
            all_mtg.each do |mtg|
              _li do
                tmp = File.join(MeetingUtil::RECORDS, File.basename(mtg))
                _a tmp, href: tmp
              end
            end
          end
        end
      end
    end
  end
end
