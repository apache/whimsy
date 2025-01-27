#!/usr/bin/env ruby
PAGETITLE = "Cross-check new Member invitations/applications" # Wvisible:meeting,members
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'date'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'mail'
require 'whimsy/asf/meeting-util'

MAIL_DIR = '/srv/mail/members'

# Get a link to lists.a.o for an email
def lists_link(email)
  mid = email[:MessageId]
  return "https://lists.apache.org/thread/<#{mid}>?<members.apache.org>" if mid
  # No mid; try another way
  datime = DateTime.parse email[:EnvelopeDate] # '2024-03-07T23:20:23+00:00'
  date1 = datime.strftime('%Y-%-m-%-d')
  date2 = (datime+1).strftime('%Y-%-m-%-d') # allow for later arrival
  from = email[:From]
  text = "Invitation to join The Apache Software Foundation Membership #{from}"
  "https://lists.apache.org/list?members@apache.org:dfr=#{date1}|dto=#{date2}:#{text}"
end

# Encapsulate gathering data to improve error processing
def setup_data
  memappfile = ASF::MeetingUtil.get_latest_file('memapp-received.txt')

  # which entries are shown as uninvited; get availid and name
  notinvited = {}
  notapplied = []
  fields = %i(invite apply mail karma id name)
  ASF::MeetingUtil.parse_memapp(memappfile).filter_map do |a|
    entry = fields.zip(a).to_h
    if entry[:invite] == 'no'
      notinvited[entry[:id]] = {name: entry[:name]}
    elsif %i(apply mail karma).any? {|e| entry[e] == 'no'} # any no apart from invite?
      notapplied << entry
    end
  end

  # find relevant email files (exclude ones before the meeting)
  yyyymm = File.basename(File.dirname(memappfile))[0..5]
  yamls = Dir[File.join(MAIL_DIR, '2?????.yaml')].select {|n| File.basename(n, 'yaml') >= yyyymm }

  # now find invitations and replies
  invites = {emails: {}, names: {}}
  replies = {emails: {}, names: {}}

  yamls.each do |index|
    mail = YamlFile.read(index)
    mail.each do |k, v|
      link = lists_link(v)
      envdate = v[:EnvelopeDate]
      age = (Date.today - Date.parse(envdate)).to_i # How long since it was
      # This may not find all the invites ...
      # Note: occasionally someone will forget to copy members@, in which case the email
      # may be sent as a reply
      # The alternative prefix has been seen in a reply from China
      # Looks like ': ' is being treated as a separate character
      if v[:Subject] =~ /^(Re: |Re：)?Invitation to join The Apache Software Foundation Membership/
        pfx = $1
        to = Mail::AddressList.new(v[:To])
        cc = Mail::AddressList.new(v[:Cc])
        (to.addresses + cc.addresses).each do |add|
          addr = add.address
          next if addr == 'members@apache.org'
          prev = invites[:emails][addr] || [nil, 100]
          if age < prev[1] # Only store later dates
            invites[:emails][addr] = [link, age] # temp save the timestamp
            invites[:names][add.display_name] = [link, age] if add.display_name
          end
        end
        if pfx # it's a reply
          add = Mail::Address.new(v[:From])
          replies[:emails][add.address] = [link, age]
          replies[:names][add.display_name] = [link, age] if add.display_name
        end
      end
    end
  end

  nominated_by = {}
  # might be more than one ...
  ASF::Person.member_nominees.each do |k, v|
    nominated_by[k.id] = v.scan(/Nominated by: (.*)/).flatten
  end

  notinvited.each do |id, v|
    mails = ASF::Person.new(id).all_mail
    v[:invited] = match_person(invites, id, v[:name], mails)
    v[:replied] = match_person(replies, id, v[:name], mails)
    v[:nominators] = nominated_by[id] || ['unknown']
  end
  notapplied.each do |record|
    id = record[:id]
    name = record[:name]
    mails = ASF::Person.new(id).all_mail
    record[:replied] = match_person(replies, id, name, mails)
    record[:invited] = match_person(invites, id, name, mails)
  end
  return notinvited, memappfile, invites, replies, nominated_by, notapplied
end

# return a link to the email (if any)
def match_person(hash, id, name, mails)
  mail = "#{id}@apache.org"
  link = hash[:emails][mail] || hash[:names][name]
  return link if link
  mails.each do |m|
    link = hash[:emails][m]
    return link if link
  end
  return nil
end

meeting_end = ASF::MeetingUtil.meeting_end
remain = ASF::MeetingUtil.application_time_remaining

# produce HTML output of reports, highlighting ones that have not (yet)
# been posted
_html do
  _style %{
    .missing {background-color: yellow}
    .flexbox {display: flex; flex-flow: row wrap}
    .flexitem {flex-grow: 1}
    .flexitem:first-child {order: 2}
    .flexitem:last-child {order: 1}
    .count {margin-left: 4em}
  }
  _body? do
    notinvited, memappfile, _, _, nominated_by, notapplied = setup_data
    memappurl = ASF::SVN.getInfoItem(memappfile, 'url')
    nominationsurl = memappurl.sub('memapp-received.txt', 'nominated-members.txt')
    _whimsy_body(
      title: PAGETITLE,
      related: {
        memappurl => 'memapp-received.txt',
        'https://lists.apache.org/list.html?members@apache.org' => 'members@apache.org',
        nominationsurl => 'nominated-members.txt',
        'https://github.com/apache/whimsy/blob/master/www/members/check_invitations.cgi' => 'Source code for this page'
      },
      helpblock: -> {
        _p do
          _ 'This script checks'
          _a 'memapp-received.txt', href: memappurl
          _ 'against invitation emails seen in'
          _a 'members@apache.org', href: 'https://lists.apache.org/list.html?members@apache.org'
        end
        _p 'It does not check against applications which are pending'
        _p 'The invite and reply columns link to the relevant emails in members@ if possible'
        _p %{
            N.B. The code only looks at the subject to determine if an email is an invite or its reply.
            Also the members@ emails are only scanned every 10 minutes or so.
        }
        _p do
          if remain[:hoursremain] > 0
            _b "Applications close in #{remain[:days]} days and #{remain[:hours]} hours"
          else
            _b "Applications can no longer be accepted, sorry."
              _ "The meeting ended at #{Time.at(meeting_end).getutc.strftime('%Y-%m-%d %H:%M %Z')}."
              _ "Applications closed #{remain[:days]} days and #{remain[:hours]} hours ago."
          end
        end
      }
    ) do

      _h1 'Nominations listed as not yet invited in memapp-received.txt'
      _p do
        _ 'If an invite or reply has been seen, the relevant table cell is'
        _span.missing 'flagged'
        _ '. After confirming that the invite was correctly identified, the memapp-received.txt file can be updated'
      end
      _table.table.table_striped do
        _tr do
          _th 'id'
          _th 'name'
          _th 'invite seen?'
          _th 'reply seen?'
          _th 'nominator(s)'
        end

        # sort by nominators to make it easier to send reminders
        notinvited.sort_by{|k,v| v[:nominators].join(', ')}.each do |id, v|
          _tr_ do
            _td do
              _a id, href: "https://whimsy.apache.org/roster/committer/#{id}"
            end
            _td v[:name]
            url, age = v[:invited]
            daysn = age == 1 ? 'day' : 'days'
            if url
              _td.missing do
                _a "#{age} #{daysn} ago", href: url
              end
            else
              _td 'false'
            end
            url, age = v[:replied]
            daysn = age == 1 ? 'day' : 'days'
            if url
              _td.missing do
                _a "#{age} #{daysn} ago", href: url
              end
            else
              _td 'false'
            end
            _td v[:nominators].join(', ')
          end
        end
      end

      _h1 'Invitees who have yet to be granted membership'
      _ 'If an invite email cannot be found, the table cell is'
      _span.missing 'flagged'
      _table.table.table_striped do
        _tr do
          _th 'invited?'
          _th 'Reply seen?'
          # No point showing these, as we don't check them
          # _th 'applied?'
          # _th 'members@?'
          # _th 'karma?'
          _th 'id'
          _th 'name'
          _th 'Nominators'
        end

        notapplied.each do |entry|
          _tr do
            url, age = entry[:invited]
            daysn = age == 1 ? 'day' : 'days'
            if url
              _td do
                _a "#{age} #{daysn} ago", href: url
              end
            else
              _td.missing 'no'
            end
            url, age = entry[:replied]
            daysn = age == 1 ? 'day' : 'days'
            if url
              _td do
                _a "#{age} #{daysn} ago", href: url
              end
            else
              _td 'no'
            end
            # _td entry[:apply]
            # _td entry[:mail]
            # _td entry[:karma]
            _td do
              _a entry[:id], href: "https://whimsy.apache.org/roster/committer/#{entry[:id]}"
            end
            _td entry[:name]
            _td (nominated_by[entry[:id]] || ['unknown']).join(' ')
          end
        end
      end
    end
  end
end

# produce JSON output
# N.B. This is activated if the ACCEPT header references 'json'
_json do
  notinvited, memappfile, invites, replies, nominated_by, notapplied = setup_data
  _notinvited notinvited
  _memappfile memappfile
  _invites invites
  _replies replies
  _nominated_by nominated_by
  _notapplied notapplied
end
