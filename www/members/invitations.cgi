#!/usr/bin/env ruby
PAGETITLE = "New Member invitations cross-check" # Wvisible:meeting,members
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'wunderbar/bootstrap'
require 'whimsy/asf'
require 'mail'
require 'whimsy/asf/meeting-util'

MAIL_DIR = '/srv/mail/members'

# Encapsulate gathering data to improve error processing
def setup_data
  memappfile = ASF::MeetingUtil.get_latest_file('memapp-received.txt')

  # which entries are shown as uninvited; get availid and name
  notinvited = {}
  notapplied = []
  ASF::MeetingUtil.parse_memapp(memappfile).filter_map do |a|
    if a.first == 'no'
      notinvited[a[-2]] = {name: a[-1]}
    elsif a[1..-3].any? {|e| e == 'no'} # any no after first?
      notapplied<<a
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
      # This may not find all the invites ...
      if v[:Subject] =~ /^Invitation to join The Apache Software Foundation Membership/
        to = Mail::AddressList.new(v[:To])
        to.addresses.each do |add|
          addr = add.address
          next if addr == 'members@apache.org'
          invites[:emails][addr] = 1
          invites[:names][add.display_name] = 1 if add.display_name
        end
      elsif v[:Subject] =~ /^Re: Invitation to join The Apache Software Foundation Membership/
        add = Mail::Address.new(v[:From])
        replies[:emails][add.address] = 1
        replies[:names][add.display_name] = 1 if add.display_name
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
    v[:nominators] = nominated_by[id] || 'unknown'
  end
  notapplied.each do |record|
    mails = ASF::Person.new(record[-2]).all_mail
    record << (match_person(replies, record[-2], record[-1], mails) ? 'yes' : 'no')
  end
  return notinvited, memappfile, invites, replies, nominated_by, notapplied
end

def match_person(hash, id, name, mails)
  mail = "#{id}@apache.org"
  return true if hash[:emails].key? mail or hash[:names].key? name
  return mails.any? {|e| hash[:emails].key? e}
end

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
      },
      helpblock: -> {
        _p 'This script checks memapp-received.txt against invitation emails seen in members@apache.org'
        _p 'It does not check against applications which are pending'
      }
    ) do

      _h1 'Nominations listed as not yet invited in memapp-received.txt'
      _p do
        _ 'If an invite or reply has been seen, the relevant table cell is'
        _span.missing 'flagged'
      end
      _table.table.table_striped do
        _tr do
          _th 'id'
          _th 'name'
          _th 'invite seen?'
          _th 'reply seen?'
          _th 'nominator(s)'
        end

        notinvited.each do |id, v|
          _tr_ do
            _td id
            _td v[:name]
            if v[:invited]
              _td.missing v[:invited]
            else
              _td v[:invited]
            end
            if v[:replied]
              _td.missing v[:replied]
            else
              _td v[:replied]
            end
            _td v[:nominators].join(', ')
          end
        end
      end

      _h1 'Invitees who have yet to be granted membership'
      _table.table.table_striped do
        _tr do
          _th 'invited?'
          _th 'Reply seen?'
          _th 'applied?'
          _th 'members@?'
          _th 'karma?'
          _th 'id'
          _th 'name'
          _th 'Nominators'
        end

        notapplied.each do |entry|
          _tr do
            a, b, c, d, e, f, g = entry
            _td a
            _td g
            _td b
            _td c
            _td d
            _td do
              _a e, href: "https://whimsy.apache.org/roster/committer/#{e}"
            end
            _td f
            _td (nominated_by[e] || 'unknown').join(' ')
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
