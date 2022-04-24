#!/usr/bin/env ruby
PAGETITLE = "Member Meeting Activity Status" # Wvisible:meeting
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar/bootstrap'
require 'date'
require 'json'
require 'tmpdir'
require 'whimsy/asf/meeting-util'

# produce HTML
_html do
  _head_ do
    _style :system
    _style %{
      div.status, .status form, pre.issue {margin-left: 16px}
      .btn {margin: 4px}
      form {margin-bottom: 1em}
      .transcript {margin: 0 16px}
      .transcript pre {border: none; line-height: 0}
      pre._hilite {background-color: yellow}
      form p {margin-top: 1em}
      form {display: inline-block}
      textarea {width: 100%; height: 8em}
      textarea:disabled {background-color: #EEEEEE}
      div.alert {background-color: yellow; border: solid 2px red; padding-top: 0}
    }
  end
  _body? do
    MEETINGS = ASF::SVN['Meetings']
    attendance = ASF::MeetingUtil.get_attendance(MEETINGS)
    latest = ASF::MeetingUtil.get_latest(MEETINGS)

    @user ||= $USER
    @meetingsMissed = (@meetingsMissed || 3).to_i

    if _.post? and @status == 'go emeritus' and $USER == @user
      # stub out roster functions
      require 'mail'
      class Committer; def self.serialize(*args); end; end
      def _committer(*args); end
      def env.user; $USER; end
      def env.password; $PASSWORD; end

      # issue request
      @action = 'request_emeritus'
      @userid = $USER
      eval IO.read(File.expand_path('../roster/views/actions/memstat.json.rb', __dir__))

      # Provide visual feedback
      _div.alert do
        _h3 'Emeritus request submitted'
        _ul do
          _li 'Check your email for confirmation.'
          _li 'Your status will be updated on Whimsy within 10 minutes.'
        end
      end
    end

    # get static/dynamic tracker
    begin
      tracker = JSON.parse(IO.read(File.join(latest, 'non-participants.json')))
    rescue Errno::ENOENT => err
      tracker = ASF::MeetingUtil.tracker(@meetingsMissed)
    end

    # determine user's name as found in members.txt
    name = ASF::Member.find_text_by_id(@user).to_s.split("\n").first
    matrix = attendance['matrix'][name]

    # defaults for active users
    tracker[@user] ||= {
      'missed' => 0,
      'status' => 'active - attended meetings recently'
    }
    active = (tracker[@user]['missed'] < @meetingsMissed)
    _whimsy_body(
      title: PAGETITLE,
      subtitle: active ? 'Your Attendance Status' : 'Poll Of Inactive Members',
      relatedtitle: 'More About Meetings',
      related: {
        'https://www.apache.org/foundation/governance/meetings' => 'How Meetings & Voting Works',
        '/members/proxy' => 'Assign A Proxy For Next Meeting',
        '/members/non-participants' => 'Members Not Participating',
        ASF::SVN.svnpath!('foundation','members.txt') => 'See Official Members.txt File',
        ASF::MeetingUtil::RECORDS => 'Official Past Meeting Records'
      },
      helpblock: -> {
        _p "This page shows your personal attendance record at past Member's meetings, as of meeting #{latest}."
        _p %{
          Inactive members (only) will see a button to request a proxy for the next meeting, and
          a second button that they can use to request to go emeritus.  They also
          will see the text of an issue that will be placed before the membership
          for a vote should they not take either of these two options.
        }
      }
    ) do

      member_status = ASF::Person.find(@user).asf_member?

      _p_ do
        if member_status != true
          _span "#{name}, your current membership status is: "
          _code member_status
        else
          _span "#{name}, your current meeting attendance status is: "
          _code tracker[@user]['status']
        end
      end

      if active and member_status == true
        att = miss = 0
        if !matrix.nil?
          matrix.each do |date, status|
            if %w(A V P).include? status
              att += 1
            elsif date != 'active'
              miss += 1
            end
          end
        end

        if 0 == miss && 0 == att
          _p.text_success "No attendance for Member's meetings found yet"
        else
          _p.text_success "Great! Thanks for attending Member's meetings recently! Overall attends: #{att} Non-attends: #{miss}"
          if 0 == miss
            _p.text_success "WOW! 100% attendance rate - thanks!"
          end
        end
      end

      if not active
        _p.alert.alert_warning "Dear #{name}, You have missed the last " +
          tracker[@user]['missed'].to_s + " meetings."

        _div.status do

          wrap = 80
          issue_text = `#{MEETINGS}/whimsy-tools/issue-description.py #{name.inspect} #{ASF::SVN['foundation']}`.
            gsub(/(.{1,#{wrap}})( +|$\n?)|(.{1,#{wrap}})/, "\\1\\3\n")

          if Dir.exist? File.join(latest, 'issues')
            _p 'Based on this status, the following text has been placed before the membership as a vote'
          else
            _p %{
              Based on this status, the following text will be placed before the membership as a vote
              unless you either assign a proxy for the next meeting or voluntarily request a conversion
              to emeritus status.
            }
          end

          _pre.issue issue_text

          _p 'Update your status (if you are inactive):'

          _form method: 'get', action: 'proxy' do
            _button.btn.btn_success 'Request a proxy',
              name: 'status', value: 'request proxy',
              disabled: $USER != @user ||
                tracker[@user]['status'] == 'Proxy received'
          end

          _form method: 'post' do
            _button.btn.btn_warning 'I would like to go emeritus',
              name: 'status', value: 'go emeritus',
              disabled: $USER != @user ||
                tracker[@user]['status'] == 'Emeritus request received'
          end

          _p_ %{
            If you haven't attended or voted in meetings recently, please consider participating, at
            least by proxy, in the upcoming membership meeting.  Assigning a proxy does NOT prevent
            you from attending meetings or
            automatically grant the assignee to the right to vote on your behalf.
          }
        end
      end

      _h1_ 'Your Attendance history', id: 'attendance'
      if not name
        _p.alert.alert_danger "#{@user} not found in members.txt"
      elsif not matrix
        _p.alert.alert_danger "#{name} not found in attendance matrix"
      else
        _table.table.table_sm style: 'margin: 0 24px; width: auto' do
          _thead do
            _tr do
              _th 'Date'
              _th 'Status'
            end
          end
          matrix.sort.reverse.each do |date, status|
            next if status == ' '
            next if date == 'active'

            color = 'bg-danger'
            color = 'bg-warning' if %w(e).include? status
            color = 'bg-success' if %w(A V P).include? status
            _tr_ class: color do
              _td do
                _a date, href:
                  ASF::SVN.svnpath!('Meetings') + date
              end
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
  end
end
