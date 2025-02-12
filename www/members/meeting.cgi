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

# Utility function for links, Note: cheezy path detection within MEETING_FILES
def emit_link(cur_mtg_dir, f, desc)
  _a desc, href: f.include?('/') && !f.start_with?('runbook/') ? f : File.join(cur_mtg_dir, f)
end

# Output action links for meeting records, depending on if current or past
# @param dt Time meeting starts
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
RECORDS_DIR = ASF::MeetingUtil::RECORDS

# produce HTML
_html do
  _body? do
    last_mtg_dir = ASF::MeetingUtil.get_latest_completed(MEETINGS)
    last_mtg_date = Time.parse(File.basename(last_mtg_dir))
    cur_mtg_dir = ASF::MeetingUtil.get_latest(MEETINGS)
    meeting = File.basename(cur_mtg_dir)
    svn_mtg_dir = File.join(RECORDS_DIR, meeting)
    # Calculate quorum
    num_members, quorum_need, num_proxies, attend_irc = ASF::MeetingUtil.calculate_quorum(cur_mtg_dir)
    proxy_nominees = ASF::MeetingUtil.getProxyNominees.count
    mtg_timeline = ASF::MeetingUtil.get_timeline(cur_mtg_dir)
    meeting_start_time = Time.parse(mtg_timeline['meeting_start_iso'])
    meeting_type = mtg_timeline.fetch('meeting_type', 'Annual')
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'Member Meeting Overview',
      relatedtitle: 'Meeting Explainers',
      related: {
        '/members/proxy' => 'PLEASE Assign A Proxy For The Meeting',
        "#{svn_mtg_dir}/README.txt" => "Detailed README for this meeting",
        "#{svn_mtg_dir}/agenda.txt" => "Actual Agenda for this meeting",
        'https://www.apache.org/foundation/governance/meetings' => 'Descriptions: how voting works:',
        'https://www.apache.org/foundation/governance/meetings#how-member-votes-are-tallied' => 'New Members Elected By Majority',
        'https://www.apache.org/foundation/governance/meetings#how-votes-for-the-board-are-tallied' => 'Board Seats Are Elected By STV',
        '/members/whatif' => 'Explore Past Board STV Results',
        '/members/non-participants' => 'Members Not Participating Recently',
        '/members/inactive' => 'Inactive Member Feedback Form',
        RECORDS_DIR => 'Official Past Meeting Records',
        'https://lists.apache.org/list.html?members@apache.org' => 'Read the members@ List Archives'
      },
      helpblock: -> {
        if Time.now > meeting_start_time
          _p do
            _ %{
              The last Member's Meeting was held #{last_mtg_date.strftime('%A, %d %B %Y')}.  Expect the
              next Annual Member's meeting to be scheduled between 12 - 13 months after the previous Annual meeting, as per
            }
            _a 'the bylaws 3.2.', href: 'https://www.apache.org/foundation/bylaws.html#3.2'
            _ 'Stay tuned for a [NOTICE] '
            _a 'email on members-notify@', href: 'https://lists.apache.org/list?members-notify@apache.org'
            _ ' announcing the next meeting.  The below information is about the '
            _strong 'LAST'
            _ " Member's meeting."
          end
        else
          _p do
            if /test/i =~ meeting_type
              _strong "NOTICE NOTICE NOTICE: This is TEST MEETING DATA ONLY - NOT AN ACTUAL MEETING :NOTICE NOTICE NOTICE"
              _br
            end
            _ "The next #{meeting_type} Member's Meeting starts at "
            _a href: "http://www.timeanddate.com/worldclock/fixedtime.html?iso=#{meeting_start_time.strftime(TADFORMAT)}" do
              _span.glyphicon.glyphicon_time ''
              _ " #{meeting_start_time.strftime(DTFORMAT)} "
            end
            _ 'as an online meeting in the'
            _strong ' NEW '
            _a 'ASFMM.apache.org chat tool', href: 'https://asfmm.apache.org'
            _ ' for less than an hour. Most activity happens in the weeks before the meeting.  Please review the meeting timeline, and some NEW PROCESS steps, or '
            _a 'see detailed FAQ about meeting files.', href: "#{svn_mtg_dir}/README.txt"
            if /test/i =~ meeting_type
              _br
              _strong "NOTICE NOTICE NOTICE: This is TEST MEETING DATA ONLY - NOT AN ACTUAL MEETING :NOTICE NOTICE NOTICE"
            end
          end
          _ul do
            _li do
              _a 'Nominations Open', href: '#nominations'
              _ ": #{mtg_timeline['nominations_open_date']} - Seconds and Statements may be added"
            end
            _li "Nominations Close: #{mtg_timeline['nominations_close_date']} - no further nominations allowed"
            _li do
              _a 'Record Date set', href: '#seconds'
              _ ": #{mtg_timeline['nominations_notice_date']} - New Member candidates list sent to members-notify@"
            end
            _li "Election Locked: #{mtg_timeline['vote_create_date']} - no further changes to Seconds, Statements"
            _li do
              _a 'Polls Open', href: '#recess'
              _ ": #{mtg_timeline['vote_open_date']} - vote online at vote.apache.org"
            end
            _li "Polls Close: #{mtg_timeline['polls_close_date']} - vote early!"
            _li do
              _a 'Online Meeting', href: '#secondhalf'              
              _ ": #{mtg_timeline['meeting_iso']} - quorum required here; expect a short meeting"
            end
            _li do
              _a 'New Member Applications', href: '#after' 
              _ " due before: #{mtg_timeline['member_form_date']}"
            end
          end
          _p do
            _ 'Currently, we will need '
            _span.text_primary attend_irc
            _ " Members who have NOT submitted a proxy to login to the online meeting #{meeting_start_time.strftime(WDAYFORMAT)} to reach quorum and continue the meeting."
            _br
            _ "Calculation: Total voting members: #{num_members}; one third for quorum: #{quorum_need}; minus previously submitted proxies: #{num_proxies}"
          end
        end
      }
    ) do
      help, copypasta = ASF::MeetingUtil.is_user_proxied(cur_mtg_dir, $USER)
      user = ASF::Person.find($USER)
      _div id: 'personal'
      _whimsy_panel("#{user.public_name} - Personal Details For Meeting #{meeting_start_time.strftime(DTFORMAT)}", style: 'panel-primary') do
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
            _ 'You have not submitted a proxy - even if you can attend the the meeting, '
            _strong 'please'
            _a " assign a proxy - it's easy!", href: '/members/proxy'
          end
        end
      end

      _div id: 'nominations'
      _whimsy_panel("Timeline: Nominations and Seconds Period", style: 'panel-default') do
        _p do
          _ 'Before an Annual meeting, Members may nominate candidates for the Board election, or as New Member Candidates.  Nominations are only official if placed in the correct files; although much discussion also happens on members@.'
         _ul do
            ['/members/nominate_board.cgi',
            '/members/nominate_member.cgi',
            '/members/proxy.cgi',
            '/members/check_boardnoms.cgi',
            '/members/check_membernoms.cgi'].each do |f|
              _li do
                emit_link(svn_mtg_dir, f, ASF::MeetingUtil::MEETING_FILES[f])
              end
            end
          end
          _ 'During this period, Members may add Seconds Statements of their own personal recommendations to various nominees.'
          _ 'Director Nominees should decide to accept the nomination, and then '
          _a 'add a Candidate Statement to their ballot', href: "#{svn_mtg_dir}/runbook/director_ballot_email.txt"
          _br 
          _strong "Nominations close at: #{mtg_timeline['nominations_close_date']}!"
        end
      end

      _div id: 'seconds'
      _whimsy_panel("Timeline: Record Date and Nominees NOTICE email (10 days before meeting)", style: 'panel-default') do
        _p do
          _ "Record date: #{mtg_timeline['nominations_notice_date']}"
        end
        _p do
          _ '10 days before the meeting, per bylaws 3.7 the official list of eligible Members is fixed, and the NOTICE of any candidates nominated for Membership will be sent out to members-notify@.'
          _ 'No further names may be added to nominations, and director candidates should have '
          _a 'added their Candidate Statement to their ballot', href: "#{svn_mtg_dir}/runbook/director_ballot_email.txt"
          _ ' before the official ballots are frozen.'
          _ul do
            ['agenda.txt', 
            '/members/check_boardnoms.cgi', 
            '/members/check_membernoms.cgi'].each do |f|
              _li do
                emit_link(svn_mtg_dir, f, ASF::MeetingUtil::MEETING_FILES[f])
              end
            end
          end
          _strong "Ballot files are frozen for vote creation at: #{mtg_timeline['vote_create_date']}!"
        end
      end

      _div id: 'firsthalf' # Pre-2022 meeting anchor

      _div id: 'recess'
      _whimsy_panel("Timeline: Voting By Email (until 24 hours before meeting)", style: 'panel-info') do
        _p do
          _strong 'NEW PROCESS simplified vote.apache.org process!'
          _ "Polls will open #{mtg_timeline['vote_open_date']}, and the vote monitors will send eligible voters an email "
          _code 'From: voter@apache.org'
          _ ' with updated instructions on voting.'
          _ 'Voting is now done by simply logging into vote.apache.org with your Apache ID - no more need for a voting key in email!'
        end
        _p do
          _strong 'REMEMBER:'
          _ "Ballots close at #{mtg_timeline['polls_close_date']} - ONE FULL DAY (24 hours) BEFORE the meeting starts - don't wait to vote!"
        end
        _p do
          _ul do
            _li do
              _a 'New Members are Elected By Majority Yes/No/Abstain vote, when elections held', href: 'https://www.apache.org/foundation/governance/meetings#membervoting'
            end
            _li do
              _a 'Board Seats Are Elected By STV at Annual Meetings - ORDER OF YOUR VOTE MATTERS!', href: 'https://www.apache.org/foundation/governance/meetings#boardvoting'
            end
            _li do
              _a 'Cast Your Votes (requires ASF Member Login)', href: "#{mtg_timeline['meeting_vote_link']}"
            end
          end
          _strong "Polls close: #{mtg_timeline['polls_close_date']}!"
        end
      end

      _div id: 'secondhalf'
      _whimsy_panel("Timeline: Online Meeting (at #{meeting_start_time.strftime(DTFORMAT)})", style: 'panel-primary') do
        _p do
          _a href: "http://www.timeanddate.com/worldclock/fixedtime.html?iso=#{meeting_start_time.strftime(TADFORMAT)}" do
            _span.glyphicon.glyphicon_time ''
            _em '(meeting time in various zones)'
          end
          _ 'The single online meeting on asfmm.apache.org is typically short - it\'s primarily briefly reporting from officers, announcing vote results and any last-minute announcements.  Members do not need to attend the meeting if you proxied or voted; all results will be emailed or checked into SVN.'
          _ul do
            _li do
              _a 'ASFMM meeting tool (requires ASF Member Login)', href: 'https://asfmm.apache.org/'
            end
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
        _p do
          _ 'Note: If quorum is not achieved within 15 minutes, the online meeting may be rescheduled - be sure to submit a proxy!'
          _ 'Various data files about the meeting (raw-irc-log, board voting tally if present) will be checked in soon after the meeting for historical records.'
          _ 'Votes for the Omnibus resolution, if any, are included in raw-irc-log.  We do not publish vote results for new member nominees.'
        end
      end

      _div id: 'after'
      _whimsy_panel("Timeline: After The Meeting", style: 'panel-default') do
        _p do
          _ 'Shortly after the live ASFMM Meeting ends, '
          _a '@TheASF twitter', href: 'https://twitter.com/theasf'
          _ ' will formally announce the new board, if an Annual meeting has elected one - please wait to retweet the official announcement.'
          _span.text_warning 'IMPORTANT:'
          _ ' Do NOT publicise the names of newly elected members!  In rare cases, the new candidate might not accept the honor.'
        end
        _p do
          _span.text_primary 'If you nominated a new member:'
          _ ' You '
          _strong 'must'
          _ ' send an email with '
          _a 'foundation/membership-application-email.txt', href: ASF::SVN.svnpath!('foundation', 'membership-application-email.txt')
          _ ' to formally invite the new member to fill out the application form; follow instructions carefully.  Applications must be signed and submitted to the secretary within 30 days of the meeting to be valid.'
        end
        _p do
          _ "REMEMBER: newly elected members must return their application before #{mtg_timeline['member_form_date']}, otherwise they are not admitted per bylaws 4.1."
        end

      end

      # Most/all of these links should already be included above
      emit_meeting(cur_mtg_dir, svn_mtg_dir, meeting_start_time, num_members, quorum_need, num_proxies, attend_irc)

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
                tmp = File.join(RECORDS_DIR, File.basename(mtg))
                _a tmp, href: tmp
              end
            end
          end
        end
      end
    end
  end
end
