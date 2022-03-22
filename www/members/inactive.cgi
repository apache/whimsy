#!/usr/bin/env ruby
PAGETITLE = "Member Meeting Activity Status" # Wvisible:meeting
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar/bootstrap'
require 'date'
require 'json'
require 'tmpdir'
require_relative 'meeting-util'

@user ||= $USER

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
      textarea {width: 100%; height: 8em}
      textarea:disabled {background-color: #EEEEEE}
    }
  end
  _body? do
    MEETINGS = ASF::SVN['Meetings']
    attendance = MeetingUtil.get_attendance(MEETINGS)
    latest = MeetingUtil.get_latest(MEETINGS)

    # get static/dynamic tracker
    begin
      tracker = JSON.parse(IO.read(File.join(latest, 'non-participants.json')))
    rescue Errno::ENOENT => err
      meetingsMissed = (@meetingsMissed || 3).to_i
      _attendance, matrix, _dates, _nameMap = MeetingUtil.get_attend_matrices(MEETINGS)
      inactive = matrix.select do |id, _name, _first, missed|
        id and missed >= meetingsMissed
      end
    
      current_status = MeetingUtil.current_status(latest)
      tracker = inactive.map {|id, name, _first, missed|
        [id, {'name' => name, 'missed' => missed, 'status' => current_status[id]}]
      }.to_h
    end

    # determine user's name as found in members.txt
    name = ASF::Member.find_text_by_id(@user).to_s.split("\n").first
    matrix = attendance['matrix'][name]

    # defaults for active users
    tracker[@user] ||= {
      'missed' => 0,
      'status' => 'active - attended meetings recently'
    }
    active = (tracker[@user]['missed'] == 0) && (ENV['QUERY_STRING'] == '')
    _whimsy_body(
      title: PAGETITLE,
      subtitle: active ? 'Your Attendance Status' : 'Poll Of Inactive Members',
      relatedtitle: 'More About Meetings',
      related: {
        'https://www.apache.org/foundation/governance/meetings' => 'How Meetings & Voting Works',
        '/members/proxy' => 'Assign A Proxy For Next Meeting',
        '/members/non-participants' => 'Members Not Participating',
        ASF::SVN.svnpath!('foundation','members.txt') => 'See Official Members.txt File',
        MeetingUtil::RECORDS => 'Official Past Meeting Records'
      },
      helpblock: -> {
        _p do
          _ "This page shows your personal attendance record at past Member's meetings, as of meeting #{latest}."
          _ %{
            It is also a poll of members who have not participated in
            ASF Members Meetings or Elections in the past three years, and
            if you have been inactive, asks you if you wish to remain active or go emeritus.  Inactive members
            (only) will see a form below and can
            indicate their choice and provide feedback on meetings by pushing one of the buttons below.
          }
        end
      }
    ) do

      _p_ do
        _span "#{name}, your current meeting attendance status is: "
        _code tracker[@user]['status']
      end
      if active
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

        if _.post? and @status and $USER == @user
          _h3_ 'Session Transcript'

          # setup authentication
          if $PASSWORD
            auth = {user: $USER, password: $PASSWORD}
          else
            auth = {}
          end

          # apply and commit changes
          Dir.mktmpdir do |dir|
            _div_.transcript do
              work = ASF::SVN.getInfoItem(latest,'url')
              ASF::SVN.svn_('checkout', [work, dir], _, {depth: 'empty'}.merge(auth))
              json = File.join(dir, 'non-participants.json')
              ASF::SVN.svn_('update', json, _, auth)
              tracker = JSON.parse(IO.read(json))
              tracker[@user]['status'] = @status
              tracker[@user]['status'] = @suggestions
              IO.write(json, JSON.pretty_generate(tracker))
              ASF::SVN.svn_('diff', json, _, {verbose: true, sysopts: {hilite: [/"status":/]}})
              ASF::SVN.svn_('commit', json, _, {msg: @status}.merge(auth))
            end
          end
        end

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

          _form method: 'post' do
            if false
              _p %{
                Please let us know how the ASF could make it easier
                for you to participate in Member's Meetings:
              }

              _textarea name: 'suggestions', disabled: active
            end

            _p 'Update your status (if you are inactive):'
            _button.btn.btn_success 'Request a proxy',
              name: 'status', value: 'request proxy',
              disabled: $USER != @user ||
                tracker[@user]['status'] == 'Proxy received'
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
