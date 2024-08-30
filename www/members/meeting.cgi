#!/usr/bin/env ruby
PAGETITLE = "Member's Meeting Information" # Wvisible:meeting
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar/bootstrap'
require 'time'
require 'json'
require 'wunderbar/jquery/stupidtable'
require 'whimsy/asf/meeting-util'
DTFORMAT = '%A, %d %B %Y at %H:%M %z'
TADFORMAT = '%Y%m%dT%H%M%S'
WDAYFORMAT = '%A'
ICS_FILE = 'ASF-members-meeting.ics' # see Meetings/meeting-template/
ERROR_DATE = Time.new(1970, 1, 1) # An obvious error value 8-)

# Return Time from DTSTART in an .ics file
def ics2dtstart(f)
  begin
    tmp = IO.readlines(f).find{ |i| i =~ /DTSTART;TZID=UTC:/ }.split(':')[1].strip
    return Time.parse(tmp)
  rescue StandardError
    return ERROR_DATE
  end
end

# Utility function for links, Note: cheezy path detection within MEETING_FILES
def emit_link(cur_mtg_dir, f, desc)
  _a desc, href: f.include?('/') && !f.start_with?('runbook/') ? f : File.join(cur_mtg_dir, f)
end

# Output action links for meeting records, depending on if current or past
def emit_meeting(cur_mtg_dir, svn_mtg_dir, dt, num_members, quorum_need, num_proxies, attend_irc)
  _div id: "meeting-#{dt.year}"
  _whimsy_panel("All Meeting Details for #{dt.strftime(DTFORMAT)}", style: 'panel-info') do
    if Time.now > dt
      _p do
        _ 'At the time of this past meeting, we had:'
        _ul do
          _li "#{num_members} eligible voting Members,"
          _li "#{quorum_need} needed for quorum (one third),"
          _li "#{num_proxies} proxy assignments available for the meeting,"
          _li "And hoped that at least #{attend_irc} would attend the start of meeting."
        end
        attendees_file = File.join(cur_mtg_dir, 'attend')
        if File.exist?(attendees_file)
          attendees = File.readlines(attendees_file)
          _ "By the end of the meeting, we had a total of #{attendees.count} Members participating (either via attending IRC, sending a proxy, or voting via email)"
        else
          _p.alert.alert_danger do
            _span "Unable to calculate participating members ("
            _code "attend"
            _span "file does not yet exist for meeting)"
          end
        end
      end
      _p "These are historical links to the past meeting's record."
    else
      _p "Live links to the upcoming meeting records/ballots/how-tos are below."
    end
    _ul do
      ASF::MeetingUtil::MEETING_FILES.each do |f, desc|
        _li do
          emit_link(svn_mtg_dir, f, desc)
        end
      end
    end
  end
end

MEETINGS = ASF::SVN['Meetings']

# produce HTML
_html do
  _body? do
    last_mtg_dir = ASF::MeetingUtil.get_latest_completed(MEETINGS)
    last_mtg_date = Time.parse(File.basename(last_mtg_dir))
    cur_mtg_dir = ASF::MeetingUtil.get_latest(MEETINGS)
    meeting = File.basename(cur_mtg_dir)
    svn_mtg_dir = File.join(ASF::MeetingUtil::RECORDS, meeting)
    # mtg_date = Time.parse(meeting)
    today = Time.now
    # Calculate quorum
    num_members, quorum_need, num_proxies, attend_irc = ASF::MeetingUtil.calculate_quorum(cur_mtg_dir)
    proxy_nominees = ASF::MeetingUtil.getProxyNominees.count
    # Use ics files for accurate times; see create-meeting.rb; note change in process 2022/2023
    ics_date = ics2dtstart(File.join(cur_mtg_dir, ICS_FILE))
    ROSTER = "/roster/committer"
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Member Meeting Overview',
      relatedtitle: 'Meeting How-Tos',
      related: {
        '/members/proxy' => 'PLEASE Assign A Proxy For The Meeting',
        'https://www.apache.org/foundation/governance/meetings' => 'How Meetings & Voting Works',
        'https://www.apache.org/foundation/governance/meetings#how-member-votes-are-tallied' => 'New Members Elected By Majority',
        'https://www.apache.org/foundation/governance/meetings#how-votes-for-the-board-are-tallied' => 'Board Seats Are Elected By STV',
        '/members/whatif' => 'Explore Past Board STV Results',
        '/members/non-participants' => 'Members Not Participating Recently',
        '/members/inactive' => 'Inactive Member Feedback Form',
        ASF::MeetingUtil::RECORDS => 'Official Past Meeting Records',
        'https://lists.apache.org/list.html?members@apache.org' => 'Read members@ List Archives'
      },
      helpblock: -> {
        if ics_date == ERROR_DATE
          _p do
            _center do
              _strong 'Note: .ics file seems to be missing!'
              _br
              _ 'Expecting to find:'
              _br
              _ul do
                _li ICS_FILE
                _li "svn_mtg_dir = #{svn_mtg_dir}, cur_mtg_dir = #{cur_mtg_dir},"
              end
            end
          end
        end
        if today > ics_date # Based on the reconvene date
          _p do
            _ %{
              The last Member's Meeting was held #{last_mtg_date.strftime('%A, %d %B %Y')}.  Expect the
              next Annual Member's meeting to be scheduled between 12 - 13 months after the previous Annual meeting, as per
            }
            _a 'https://www.apache.org/foundation/bylaws.html#3.2', 'the bylaws 3.2.'
            _ 'Stay tuned for a [NOTICE] '
            _a 'https://lists.apache.org/list?members-notify@apache.org', 'email on members-notify@'
            _ ' announcing the next meeting.  The below information is about the '
            _strong 'LAST'
            _ " Member's meeting."
          end
        else
          _p do
            _ "The Member's Meeting starts at "
            _a href: "http://www.timeanddate.com/worldclock/fixedtime.html?iso=#{ics_date.strftime(TADFORMAT)}" do
              _span.glyphicon.glyphicon_time ''
              _ " #{ics_date.strftime(DTFORMAT)} "
            end
            _ "as an online "
            _a 'https://asfmm.apache.org', "ASFMM chat tool meeting"
            _ " for less than an hour.  REMEMBER: all voting is done by email the week BEFORE the ASFMM meeting."
          end
          _p do
            _ 'Please read below for a Timeline of Meeting activities and links to how you can take action, or see additional links to the right. '
            _strong 'REMINDER: '
            _ 'Nominations for the board or new members (when being held) close 10 days before the meeting starts; no new names may be added after that date.'
          end
          _p do
            _ 'Currently, we need '
            _span.text_primary attend_irc
            _ " Members who have NOT submitted a proxy, to attend the meeting on #{ics_date.strftime(WDAYFORMAT)} and respond to Roll Call to reach quorum and continue the meeting, so that between Members actually attending, and Members who have assigned a proxy are counted as attending."
            _ " Calculation: Total voting members: #{num_members}, with one third for quorum: #{quorum_need}, minus previously submitted proxies: #{num_proxies}"
          end
          _p do
            _ "There are #{proxy_nominees} people acting as proxies."
            if proxy_nominees >= attend_irc
              _strong 'If they all attend, then quorum will be achieved.'
            end
          end
          _p 'Individual Members are considered to have Attended a meeting if they either: respond to Roll Call in the meeting; submit a proxy (this gets submitted during Roll Call); or who cast a ballot on any matters.'
          _ul do
            _li '2024 March Annual Meeting dates:'
            _li 'Nominations open: February 06'
            _li 'Nominations close: February 24, 2024 at 20:00'
            _li 'Ballots emailed: February 29, 2024'
            _li 'Voting closes: March 06, 2024 20:00 UTC (single IRC meeting March 07, 2024 20:00 UTC)'
          end
          _p 'The above dates are manually copied from https://svn.apache.org/repos/private/foundation/Meetings/20240307/README.txt'
          _p 'The file to edit is at: https://github.com/apache/whimsy/blob/master/www/members/meeting.cgi'
        end
      }
    ) do
      # if there is a new meeting in the offing, use its date
      # Old logic for two half meeting m1_date = mtg_date if m1_date == ERROR_DATE && cur_mtg_dir > last_mtg_dir
      help, copypasta = ASF::MeetingUtil.is_user_proxied(cur_mtg_dir, $USER)
      # attendance = JSON.parse(IO.read(File.join(MEETINGS, 'attendance.json')))
      user = ASF::Person.find($USER)
      _div id: 'personal'
      _whimsy_panel("#{user.public_name} - Personal Details For Meeting #{ics_date.strftime(DTFORMAT)}", style: 'panel-primary') do
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
            _ 'You have not submitted a proxy - even if you can attend the first half of the meeting, '
            _a "please assign a proxy - it's easy!", href: '/members/proxy'
          end
        end
        _p do
          _span.text_warning 'REMINDER: '
          _ "Voting ballots are sent to your official email address as found in members.txt, please double-check it is correct!"
          _a 'See members.txt', href: ASF::SVN.svnpath!('foundation', 'members.txt')
        end
      end

      _div id: 'nominations'
      _whimsy_panel("Timeline: Nomination Period (until 10 days BEFORE meeting)", style: 'panel-default') do
        _p do
          _ 'Before any Annual meeting, any Member may nominate people either for the Board, or as a New Member Candidate.  Much of this discussion happens on members@ mailing list.  Remember, all new nominated names must be checked into SVN 10 days before the meeting.'
          _ 'Also, you should submit a proxy if you might not attend the the meeting.'
          _ul do
            ['board_nominations.txt', 'board_ballot.txt', '/members/board-nominate.cgi', '/members/board_nominations.cgi',
              'nominated-members.txt', '/members/member_nominations.cgi', '/members/nominations.cgi',
              '/members/proxy.cgi'].each do |f|
              _li do
                emit_link(svn_mtg_dir, f, ASF::MeetingUtil::MEETING_FILES[f])
              end
            end
          end
        end
      end

      _div id: 'seconds'
      _whimsy_panel("Timeline: Seconds Period (last ten days before meeting)", style: 'panel-default') do
        _p do
          _ 'The last 10 days before the meeting, you may add seconds (comments of support) to existing nomination files, but no new nominations are allowed.'
          _ 'Also, you can still submit a proxy.'
          _ul do
            ['nominated-members.txt', '/members/proxy.cgi'].each do |f|
              _li do
                emit_link(svn_mtg_dir, f, ASF::MeetingUtil::MEETING_FILES[f])
              end
            end
          end
        end
      end

      _div id: 'firsthalf' # Pre-2022 meeting anchor

      _div id: 'recess'
      _whimsy_panel("Timeline: Voting By Email (week before meeting)", style: 'panel-info') do
        _p do
          _ 'One week before the meeting, the STeVe vote monitors will send you an email '
          _code 'From: voter@apache.org'
          _ ' with your voting key URL.'
          _ 'All voting is done via a simple web interface at vote.apache.org after you login with your Apache ID.'
          _b 'REMEMBER:'
          _ "Ballots close ONE FULL DAY (24 hours) BEFORE the meeting starts - don't wait to vote!"
          _ul do
            _li do
              _a 'New Members Elected By Majority Yes/No/Abstain vote, when elections held', href: 'https://www.apache.org/foundation/governance/meetings#how-member-votes-are-tallied'
            end
            _li do
              _a 'Board Seats Are Elected By STV at Annual Meetings - ORDER OF YOUR VOTE MATTERS!', href: 'https://www.apache.org/foundation/governance/meetings#how-votes-for-the-board-are-tallied'
            end
          end
        end
      end

      _div id: 'secondhalf'
      _whimsy_panel("Timeline: Meeting (at #{ics_date.strftime(DTFORMAT)})", style: 'panel-primary') do
        _p do
          _a href: "http://www.timeanddate.com/worldclock/fixedtime.html?iso=#{ics_date.strftime(TADFORMAT)}" do
            _span.glyphicon.glyphicon_time ''
            _em '(time)'
          end
          _ 'The meeting is typically short - it\'s primarily briefly reporting from officers, announcing vote results and any last-minute announcements.  Members do not need to attend the meeting if you proxied or voted; all results will be emailed or checked into SVN.'
          _ 'Various data files about the meeting (raw-irc-log, board voting tally if present) will be checked in within soon after the meeting for historical records.'
          _ 'Votes for the Omnibus resolution, if any, are included in raw-irc-log.  We do not publish vote results for new member nominees.'
          _ul do
            ['record', 'attend', 'voter-tally', 'raw_board_votes.txt', 'raw-irc-log'].each do |f|
              _li do
                emit_link(svn_mtg_dir, f, ASF::MeetingUtil::MEETING_FILES[f])
              end
            end
            _li do
              _a 'What-If tool for analyzing Board STV votes', href: '/members/whatif'
            end
          end
        end
      end

      _div id: 'after'
      _whimsy_panel("Timeline: After This Meeting", style: 'panel-default') do
        _p do
          _ 'Shortly after the live ASFMM Meeting ends, '
          _a '@TheASF twitter', href: 'https://twitter.com/theasf'
          _ ' will formally announce the new board, if an Annual meeting has elected one - please wait to retweet the official announcement.'
          _span.text_warning 'IMPORTANT:'
          _ ' Do not publicise the names of newly elected members!  In rare cases, the new candidate might not accept the honor.'
        end
        _p do
          _span.text_primary 'If you nominated a new member:'
          _ ' You '
          _b 'must'
          _ ' send an email with '
          _a 'foundation/membership-application-email.txt', href: ASF::SVN.svnpath!('foundation', 'membership-application-email.txt')
          _ ' to formally invite the new member to fill out the application form.  Applications must be signed and submitted to the secretary within 30 days of the meeting to be valid.'
        end
      end

      # Most/all of these links should already be included above
      emit_meeting(cur_mtg_dir, svn_mtg_dir, ics_date, num_members, quorum_need, num_proxies, attend_irc)

      _div id: 'meeting-history'
      _whimsy_panel("Member Meeting History", style: 'panel-info') do
        all_mtg = Dir[File.join(MEETINGS, '19*'), File.join(MEETINGS, '2*')].sort
        _p do
          _ %{
            The ASF has held #{all_mtg.count} Member's meetings in our
            history. Some were Annual meetings, where we elect a new board;
            a handful were Special mid-year meetings where we mostly just
            elected new Members.
          }
          _ ' Remember, member meeting minutes are '
          _span.text_warning 'private'
          _ ' to the ASF. You can see your '
          _a 'your own Attendance history at meetings.', href: '/members/inactive#attendance'
          _ 'Various data files and tools tracking Attendance at meetings are in '
          _code 'foundation/Meetings/attend*'
          _ul do
            all_mtg.each do |mtg|
              _li do
                tmp = File.join(ASF::MeetingUtil::RECORDS, File.basename(mtg))
                _a tmp, href: tmp
              end
            end
          end
        end
      end
    end
  end
end
