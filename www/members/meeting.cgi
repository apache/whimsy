#!/usr/bin/env ruby
PAGETITLE = "Member's Meeting Information" # Wvisible:meeting
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar/bootstrap'
require 'date'
require 'json'
require 'wunderbar/jquery/stupidtable'
require_relative 'meeting-util'
FOUNDATION_SVN = 'https://svn.apache.org/repos/private/foundation/'

# Utility function for links, Note: cheezy path detection within MEETING_FILES
def emit_link(cur_mtg_dir, f, desc)
  _a desc, href: f.include?('/') ? f : File.join(cur_mtg_dir, f)
end

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
        _li do
          emit_link(cur_mtg_dir, f, desc)
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
    begin
      ics = IO.read(File.join(cur_mtg_dir, "ASF-members-#{mtg_date.strftime('%Y')}.ics"))
    rescue StandardError => e
      # Ensure we can't break rest of script
      puts "ERROR: #{e}"
      return 0, 0, 0, 0
    end

    ROSTER = "/roster/committer"
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Meeting How-Tos',
      relatedtitle: 'More About Meetings',
      related: {
        'https://www.apache.org/foundation/governance/meetings' => 'How Meetings & Voting Works',
        'https://www.apache.org/foundation/governance/meetings#how-member-votes-are-tallied' => 'New Members Elected By Majority',
        'https://www.apache.org/foundation/governance/meetings#how-votes-for-the-board-are-tallied' => 'Board Seats Are Elected By STV',
        '/members/whatif' => 'Explore Past Board STV Results',
        '/members/proxy' => 'Assign A Proxy For Next Meeting',
        '/members/non-participants' => 'Members Not Participating',
        '/members/inactive' => 'Inactive Member Feedback Form',
        MeetingUtil::RECORDS => 'Official Past Meeting Records'
      },
      helpblock: -> {
        if today > meeting # Date is start of the two day meeting
          _p do
            _ %{
              The last Annual Member's Meeting was held #{mtg_date.strftime('%A, %d %B %Y')}.  Expect the 
              next Member's meeting to be scheduled between 12 - 13 months after 
              the previous meeting, as per 
            }
            _a 'https://www.apache.org/foundation/bylaws.html#3.2', 'the bylaws 3.2.'
            _ 'Stay tuned for a NOTICE email on members@ announcing the next meeting.  The below information is about the '
            _span.text_warning 'LAST'
            _ " Member's meeting."
          end
        else
          _p do
            _ "The next Member's Meeting will start on #{mtg_date.strftime('%A, %d %B %Y')}, as an online meeting on IRC, and will finish up two days later after voting via email is held."
            _ 'Please read below for a Timeline of Meeting activities and links to how you can take action, or see additional links to the right. '
            _span.text_warning 'REMINDER: '
            _ 'Nominations for the board or new members close 10 days before the meeting starts; no new names may be added after that date.'
          end
        end
      }
    ) do
      help, copypasta = MeetingUtil.is_user_proxied(cur_mtg_dir, $USER)
      attendance = JSON.parse(IO.read(File.join(MEETINGS, 'attendance.json')))
      user = ASF::Person.find($USER)
      _whimsy_panel("#{user.public_name} Details For Meeting #{meeting}", style: 'panel-primary') do
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
        _p do
          _span.text_warning 'REMINDER: '
          _ "Ballots are sent to your official email address as found in members.txt, please double-check it is correct!"
          _a 'See members.txt', href: "#{FOUNDATION_SVN}members.txt"
        end
      end

      _whimsy_panel("Timeline: Nomination Period (now until TEN DAYS before the meeting)", style: 'panel-default') do
        _p do
          _ 'Before the meeting, any Member may nominate people either for the Board, or as a New Member Candidate.  Much of this discussion happens on members@ mailing list.  Remember, all new nominated names must be checked into SVN 10 days before the meeting.'
          _ 'Also, you should submit a proxy if you might not attend the first half of the meeting.'
          _ul do
            ['nomination_of_board.txt', 'nomination_of_members.txt', '/members/proxy.cgi'].each do |f|
              _li do
                emit_link(cur_mtg_dir, f, MeetingUtil::MEETING_FILES[f])
              end
            end
          end
        end
      end
      
      _whimsy_panel("Timeline: Seconds Period (last ten days before meeting)", style: 'panel-default') do
        _p do
          _ 'The 10 days before the meeting, you may add seconds to existing nomination files, but no new nominations are allowed.'
          _ 'Also, you can still submit a proxy if you might not attend the first half of the meeting.'
          _ul do
            ['nominated-members.txt', '/members/proxy.cgi'].each do |f|
              _li do
                emit_link(cur_mtg_dir, f, MeetingUtil::MEETING_FILES[f])
              end
            end
          end
        end
      end
      
      _whimsy_panel("Timeline: First Half Of Meeting on IRC (at #{mtg_date.strftime('%A, %d %B %Y')})", style: 'panel-primary') do
        _p do
          _ 'The Meeting itself starts on IRC - please be sure your client is setup ahead of time, and sign in with your Apache ID as nick if at all possible.'
          _ 'The #asfmembers channel is for the official meeting itself; please raise your hand if you have a formal question there.  Backchannel (jokes, comments, etc.) is on #asf channel.'
          _ 'During the First Half of Meeting, the Chairman and various officers run through reports in the Agenda, which you can read ahead of time.'
          _ 'Expect the First Half to last about an hour; then the Chairman will call for a recess.'
          _ul do
            ['agenda.txt', 'README.txt', 'https://www.apache.org/foundation/governance/meetings'].each do |f|
              _li do
                emit_link(cur_mtg_dir, f, MeetingUtil::MEETING_FILES[f])
              end
            end
          end
        end
      end
      
      _whimsy_panel("Timeline: Meeting Recess To Vote Via Email (approx 40+ hours)", style: 'panel-info') do
        _p do
          _ 'Shortly after the Chairman calls the recess, the STeVe vote monitors will send you multiple emails with your voting keys.'
          _ 'All voting is done via a simple web interface at vote.apache.org after you login with your Apache ID.'
          _ul do
            _li do
              _a 'New Members Elected By Majority Yes/No/Abstain vote', href: 'https://www.apache.org/foundation/governance/meetings#how-member-votes-are-tallied'
              _a 'Board Seats Are Elected By STV - ORDER OF YOUR VOTE MATTERS!', href: 'https://www.apache.org/foundation/governance/meetings#how-votes-for-the-board-are-tallied'
            end
          end
        end
      end
      
      _whimsy_panel("Timeline: Second Half Of Meeting (48 hours after #{mtg_date.strftime('%A, %d %B %Y')})", style: 'panel-primary') do
        _p do
          _ 'The Second Half Meeting is short - it\'s primarily announcing vote results and any last-minute announcements.  Members do not need to attend the second half; all results will be emailed or checked into SVN.'
          _ 'Various data files about the meeting will be checked in within a day after the meeting for historical records.'
          _ul do
            ['record', 'attend', 'voter-tally', 'raw_board_votes.txt'].each do |f|
              _li do
                emit_link(cur_mtg_dir, f, MeetingUtil::MEETING_FILES[f])
              end
            end
          end
        end
      end
      
      _whimsy_panel("Timeline: After This Year's Meeting", style: 'panel-default') do
        _p do 
          _ 'Shortly after the second half Meeting ends, '
          _a '@TheASF twitter', href: 'https://twitter.com/theasf'
          _ ' will formally announce the new board - please wait to retweet the official announcement.'
          _span.text_warning 'IMPORTANT:'
          _ ' Do not publicise the names of newly elected members!  In rare cases, the new candidate might not accept the honor.'
        end
        _p do
          _span.text_primary 'If you nominated a new member:'
          _ ' You must send an email with '
          _a 'foundation/membership-application-email.txt', href: "#{FOUNDATION_SVN}membership-application-email.txt"
          _ ' to formally invite the new member to fill out the application form.  Applications must be signed and submitted to the secretary within 30 days of the meeting to be valid.'
        end
      end
      
      # Most/all of these links should already be included above
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
