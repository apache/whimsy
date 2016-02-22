#!/usr/bin/ruby1.9.1
$LOAD_PATH.unshift File.expand_path('../../../lib', __FILE__)
require 'wunderbar'
require 'whimsy/asf'
require 'whimsy/asf/podlings'
require 'whimsy/asf/site'

SUBSCRIPTIONS = '/srv/subscriptions/board'

info_chairs = ASF::Committee.load_committee_info.group_by(&:chair)
ldap_chairs = ASF.pmc_chairs

_html do
  _head_ do
    _title 'Apache pmc-chair/board list'
    _style %{
      table {border-collapse: collapse}
      th, td { border: 1pt solid black}
      .issue, .issue a {color: red}
    }
  end

  _body? do

    _h1 'Apache pmc-chair/board list'

    _p! do
      _ 'This process starts with the list of subscribers to '
      _a 'board@apache.org', href: 'https://mail-search.apache.org/members/private-arch/board/'
      _ '.  '
      _a 'members.txt', href: 'https://svn.apache.org/repos/private/foundation/members.txt'
      _ ', '
      _a 'iclas.txt', href: 'https://svn.apache.org/repos/private/foundation/officers/iclas.txt'
      _ ', and '
      _code 'ldapsearch mail'
      _ ' to attempt to match the email address to an Apache ID.  '
      _ 'Those that are not found are listed as '
      _code.issue '*missing*'
      _ '.  ASF members are '
      _strong 'listed in bold'
      _ '.  Emeritus members are '
      _em 'listed in italics'
      _ '.  Non ASF member, non-committee chairs are also '
      _span.issue 'listed in red'
      _ '.'
    end

    _p! do
      _ 'The resulting list is then cross-checked against '
      _a 'committee-info.text', href: 'https://svn.apache.org/repos/private/committers/board/committee-info.txt'
      _ ' and '
      _code 'ldapsearch cn=pmc-chairs'
      _ '.  Membership that is only listed in one of these two sources is '
      _span.issue 'listed in red'
      _ '.'
    end

    _p! do
      _ 'Committee chairs for which a matching email address can not be found are '
      _a 'listed in a separate table', href: "#unsub"
      _ '.'
    end

    ids = []
    maillist = ASF::Mail.list

    File.readlines(SUBSCRIPTIONS).each do |line|
      person = maillist[line.downcase.strip]
      person ||= maillist[line.downcase.strip.sub(/\+\w+@/,'@')]
      if person
        id = person.id
        id = '*notinavail*' if id == 'notinavail'
      else
        person = ASF::Person.find('notinavail')
        id = '*missing*'
      end
      ids << [id, person, line.strip]
    end

    _table_ border: '1', cellpadding: '2', cellspacing: '0' do
      _tr do
        _th 'id'
        _th 'email'
        _th 'name'
        _th 'committee'
      end

      ids.sort.each do |id, person, email|
        next if email == 'board-archive@apache.org'
        _tr_ do
          href = "/roster/committer/#{id}"
          if person.asf_member?
            if person.asf_member? == true
              _td! {_strong {_a id, href: href}}
            else
            _td! {_em {_a id, href: href}}
            end
          elsif id.include? '*'
            _td.issue id
          elsif info_chairs.include? person or ldap_chairs.include? person
            _td {_a id, href: href}
          else
            _td.issue {_a id, href: href}
          end
          _td email

          if not id.include? '*'
            _td person.public_name
          else
            icla = ASF::ICLA.find_by_email(id)
            if icla
              _td.issue icla.name
            else
              _td.issue '*notinavail*'
            end
          end

          if info_chairs.include? person
            text = info_chairs[person].uniq.map(&:display_name).join(', ')
            if ldap_chairs.include? person or info_chairs[person].all? &:nonpmc?
              _td text
            else
              _td.issue text
            end
          elsif ldap_chairs.include? person
            _td.issue '***LDAP only***'
          elsif person.asf_member?
            _td
          else
            _td.issue '*** non-member, non-officer ***'
          end
        end
      end
    end

    chairs = ( info_chairs.keys + ldap_chairs ).uniq
    missing = chairs.map(&:id) - ids.map(&:first)

    unless missing.empty?
      _h3_.unsub! 'Not subscribed to the list'
      _table border: '1', cellpadding: '2', cellspacing: '0' do
        _tr do
          _th 'id'
          _th 'name'
          _th 'committee'
        end
        missing.sort.each do |id|
          person = ASF::Person.find(id)
          _tr_ do
            if person.asf_member?
              _td! {_strong id}
            else
              _td id
            end
            _td person.public_name
            if info_chairs.include? person
              text = info_chairs[person].uniq.map(&:display_name).join(', ')
              if ldap_chairs.include? person
                _td text
              else
                _td.issue text
              end
            elsif ldap_chairs.include? person
              _td.issue '***LDAP only***'
            else
              _td
            end
          end
        end
      end
    end
  end
end
