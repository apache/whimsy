#!/usr/bin/env ruby
PAGETITLE = "Cross-check new Member invitations/applications" # Wvisible:meeting,members
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'date'
require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'mail'
require 'whimsy/asf/meeting-util'
require 'whimsy/asf/member-files'
require 'yaml'

MAIL_DIR = '/srv/mail/members'
MAIL_DIR_SEC = '/srv/mail/secretary'

ENV['HTTP_ACCEPT'] = 'application/json' if ENV['QUERY_STRING'].include? 'json'

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
    entry[:id] = 'n/a_' + entry[:name] if entry[:id] == 'n/a' # Allow for n/a entries
    if entry[:invite] == 'no'
      notinvited[entry[:id]] = {name: entry[:name]}
    elsif %i(apply mail karma).any? {|e| entry[e] == 'no'} # any no apart from invite?
      notapplied << entry
    end
  end

  yyyymm = File.basename(File.dirname(memappfile))[0..5]
  
  applications = []
  # find relevant secretary files (exclude ones before the meeting)
  syamls = Dir[File.join(MAIL_DIR_SEC, '2?????.yml')].select {|n| File.basename(n, 'yml') >= yyyymm }
  syamls.each do |index|
    mail = YamlFile.read(index)
    mail.each do |k, v|
      next if v[:status] == :deleted
      next unless v[:attachments] and v[:attachments].size > 0
      if (v['Subject'] =~ %r{[Mm]embership}) or (v[:attachments].first[:name] =~ %r{[Mm]embership})
        applications << v[:from]
        name = v['From'].sub(%r{<[^>\s]+>}, '').strip
        applications << name if name
      end
    end
  end

  # find relevant members email files (exclude ones before the meeting)
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
      # Allow for forwarded mail (may not catch original and reply ...)
      if v[:Subject] =~ /^(R[eE]: ?|R[eE]：|AW: )?(?:Fwd: )?Invitation to (?:re-)?join The Apache Software Foundation/
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
  na_emails = {} # emails for n/a ids from member-nominations
  # n/a entries are not necessarily in the same order as in member-apps
  ASF::MemberFiles.member_nominees.each do |k, v|
    if k.start_with? 'n/a_'
      k = 'n/a_' + v['Public Name']
      na_emails[k] = [v['Nominee email']]
    end
    nominated_by[k] = v['Nominated by']
  end

  # Load extra emails from override file if it exists
  begin
    extras = YAML.load_file(File.join(File.dirname(memappfile),'notinavail.yml'))
    extras[:emails].each do |name, email|
      k = 'n/a_' + name
      na_emails[k] ||= []
      na_emails[k] += email
    end
  rescue StandardError
    # ignored
  end

  notinvited.each do |id, v|
    # na_emails entries only exist for non-commiters
    mails = na_emails[id] || ASF::Person.new(id).all_mail
    v[:invited] = match_person(invites, id, v[:name], mails)
    v[:replied] = match_person(replies, id, v[:name], mails)
    v[:nominators] = nominated_by[id] || ['unknown']
  end
  notapplied.each do |record|
    id = record[:id]
    name = record[:name]
    # na_emails entries only exist for non-commiters
    mails = na_emails[id] || ASF::Person.new(id).all_mail
    record[:replied] = match_person(replies, id, name, mails)
    record[:invited] = match_person(invites, id, name, mails)
    record[:applied] = applications.any? {|x| mails.include? x or x == name}
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
          _ 'against invitation emails and replies seen in'
          _a 'members@apache.org', href: 'https://lists.apache.org/list.html?members@apache.org'
        end
        _p do
          _ 'It also tries to check against applications which are pending processing by the secretary.'
          _ 'These must have a subject or attachment name that mentions "membership".'
          _ 'Also, the From address must be one of the ones registered to the applicant, or must match the full name.'
        end
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
        notinvited.sort_by{|k,v| v[:nominators]}.each do |id, v|
          _tr_ do
            _td do
              if id.start_with? 'n/a_'
                _ id
              else
                _a id, href: "https://whimsy.apache.org/roster/committer/#{id}"
              end
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
            _td v[:nominators]
          end
        end
      end

      _h1 'Invitees who have yet to be granted membership'
      _ 'If an invite email (or reply) cannot be found, the table cell is'
      _span.missing 'flagged'
      _p do
        _ 'There is currently no way to record declined invitations.'
        _ 'Nor is there a way to record replies that do not match the list search criteria.'
        _br
        _ 'Some replies may be incorrectly recorded as missing'
        _ 'and some applications will never be received.'
      end
      _table.table.table_striped do
        _tr do
          _th 'invited?'
          _th 'Reply seen?'
          # No point showing these, as we don't check them
          # _th 'applied?'
          # _th 'members@?'
          # _th 'karma?'
          _th 'Application seen?'
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
              if entry[:applied]
                _td.missing 'no'
              else
                _td 'no'
              end
            end
            # _td entry[:apply]
            # _td entry[:mail]
            # _td entry[:karma]
            _td entry[:applied] ? 'yes' : 'no'
            _td do
              if entry[:id].start_with? 'n/a_'
                _ entry[:id]
              else
                _a entry[:id], href: "https://whimsy.apache.org/roster/committer/#{entry[:id]}"
              end
            end
            _td entry[:name]
            _td nominated_by[entry[:id]] || 'unknown'
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
