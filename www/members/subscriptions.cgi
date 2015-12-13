#!/usr/bin/ruby1.9.1
require 'wunderbar'
require 'whimsy/asf'
require 'whimsy/asf/podlings'
require 'whimsy/asf/site'

SUBSCRIPTIONS = '/home/apmail/subscriptions/members'

_html do
  _head_ do
    _title 'Apache Members cross-check'
    _style %{
      table {border-collapse: collapse}
      th, td { border: 1pt solid black}
      .issue {color: red}
    }
  end

  _body? do

    _h1_ 'Apache Members cross-check'

    _p! do
      _ 'This process starts with the list of subscribers to '
      _a 'members@apache.org', href: 'https://mail-search.apache.org/members/private-arch/members/'
      _ '.  It then uses '
      _a 'members.txt', href: 'https://svn.apache.org/repos/private/foundation/members.txt'
      _ ', '
      _a 'iclas.txt', href: 'https://svn.apache.org/repos/private/foundation/officers/iclas.txt'
      _ ', and '
      _code 'ldapsearch mail'
      _ ' to attempt to match the email address to an Apache ID.  '
      _ 'Those that are not found are listed as '
      _code.issue '*missing*'
      _ '.  Emeritus members are '
      _em 'listed in italics'
      _ '.  Non ASF members are '
      _span.issue 'listed in red'
      _ '.'
    end

    _p! do
      _ 'The resulting list is then cross-checked against '
      _code 'ldapsearch cn=member'
      _ '.  Membership that is only listed in one of these two sources is also '
      _span.issue 'listed in red'
      _ '.'
    end

    _p! do
      _ 'ASF members for which a matching email address can not be found are '
      _a 'listed in a separate table', href: "#unsub"
      _ '.'
    end

    ldap = ASF::Group['member'].members

    members = ASF::Member.new.map {|id, text| ASF::Person[id]}
    ASF::Person.preload('cn', members)

    subscriptions = []
    File.readlines(SUBSCRIPTIONS).each do |line|
      person = ASF::Mail.list[line.downcase.strip]
      person ||= ASF::Mail.list[line.downcase.strip.sub(/\+\w+@/,'@')]
      if person
        id = person.id
        id = '*notinavail*' if id == 'notinavail'
      else
        person = ASF::Person.find('notinavail')
        id = '*missing*'
      end
      subscriptions << [id, person, line.strip]
    end

    _table_ border: '1', cellpadding: '2', cellspacing: '0' do
      _tr do
        _th 'id'
        _th 'email'
        _th 'name'
      end
      subscriptions.sort.each do |id, person, email|
        next if email == 'members-archive@apache.org'
        _tr_ do
          if id.include? '*'
            _td.issue id
          elsif not person.asf_member?
            _td.issue id, title: 'Non Member'
          elsif person.asf_member? != true
            _td {_em id, title: 'Emeritus'}
          elsif not ldap.include? person
            _td {_strong.issue id, title: 'Not in LDAP'}
          else
            _td id
          end
          _td email

          if id.include? '*'
            _td ''
          else
            _td person.public_name
          end
        end
      end
    end

    missing = members - (subscriptions.map {|id,person,email| person})
    missing.delete_if {|person| person.asf_member? != true} # remove emeritus

    unless missing.empty?
      _h3_.unsub! 'Not subscribed to the list'
      _table border: 1, cellpadding: 2, cellspacing: 0 do
	_tr_ do
	  _th 'id'
	  _th 'name'
	end
	missing.sort_by(&:name).each do |person|
	  _tr do
	    if not ldap.include? person
	      _td {_strong.issue person.id, title: 'Not in LDAP'}
	    else
	      _td person.id
	    end
            if person.public_name
	      _td person.public_name
            else
              _td.issue '*notinavail*'
            end
	  end
	end
      end
    end

    extras = ldap - members

    unless extras.empty?
      _h3_.ldap! 'In LDAP but not in members.txt'
      _table border: 1, cellpadding: 2, cellspacing: 0 do
	_tr_ do
	  _th 'id'
	  _th 'name'
	end
	extras.sort.each do |person|
	  _tr do
	    _td person.id
	    _td person.public_name
	  end
	end
      end
    end
  end
end
