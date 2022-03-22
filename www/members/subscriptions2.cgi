#!/usr/bin/env ruby

# TODO: combine with members@ script

PAGETITLE = "Apache members-notify@ Subscription Crosscheck" # Wvisible:members
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'wunderbar'
require 'whimsy/asf'
require 'whimsy/asf/mlist'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery/stupidtable'

subscribers, modtime = ASF::MLIST.members_notify_subscribers(false) # excluding archivers

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        '/roster/members' => 'Listing Of All Members',
        '/committers/subscribe' => 'Committers Self-Subscribe Tool',
        'https://lists.apache.org' => 'Apache Ponymail List Archives'
      },
      helpblock: -> {
        _p! do
          _ "This process starts with the list of subscribers (updated #{modtime}) to "
          _a 'members-notify@apache.org', href: 'https://mail-search.apache.org/members/private-arch/members-notify/'
          _br
          _ 'These are matched against '
          _a 'members.txt', href: ASF::SVN.svnpath!('foundation', 'members.txt')
          _ ', '
          _a 'iclas.txt', href: ASF::SVN.svnpath!('officers', 'iclas.txt')
          _ ', and '
          _code 'ldapsearch mail'
          _ ' to attempt to match the email address to an Apache ID.'
          _br
          _ 'Those that are not found are listed as '
          _code.text_danger '*missing*'
          _ '.  Emeritus members are '
          _em 'listed in italics'
          _ '.  Non ASF members are '
          _span.text_danger 'listed in red'
          _ '.'
        end
        _p! do
          _ 'The resulting list is then cross-checked against '
          _code 'ldapsearch cn=member'
          _ '.  Membership that is only listed in one of these two sources is also '
          _span.text_danger 'listed in red'
          _ '.'
        end
        _p! do
          _ 'Separate tables below show '
          _a 'Members not subscribed to the list', href: "#unsub"
          _ ', and '
          _a 'Copyable list of Members not subscribed', href: "#unsublist"
          _ ', and '
          _a 'Entries in LDAP but not members.txt', href: "#ldap"
          _ '.'
        end
      }
    ) do
    ldap = ASF.members

    members = ASF::Member.new.map {|id, _text| ASF::Person.find(id)}
    ASF::Person.preload('cn', members)
    maillist = ASF::Mail.list

    subscriptions = []
    subscribers.each do |line|
      person = maillist[line.downcase]
      person ||= maillist[line.downcase.sub(/[-+]\w+@/, '@')] # allow for trailing +- suffix
      if person
        id = person.id
        id = '*notinavail*' if id == 'notinavail'
      else
        person = ASF::Person.find('notinavail')
        id = '*missing*'
      end
      subscriptions << [id, person, line]
    end

    _table.table do
      _thead_ do
        _tr do
          _th 'id', data_sort: 'string'
          _th 'email', data_sort: 'string'
          _th 'name', data_sort: 'string'
        end
      end
      _tbody do
        subscriptions.sort.each do |id, person, email|
          _tr_ do
            if id.include? '*'
              _td.text_danger id
            elsif not person.asf_member?
              _td.text_danger id, title: 'Non Member', data_sort_value: '1'
            elsif person.asf_member? != true
              _td(data_sort_value: '2') {_em id, title: 'Emeritus'}
            elsif not ldap.include? person
              _td(data_sort_value: '3')  {_strong.text_danger id, title: 'Not in LDAP'}
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
    end

    missing = members - (subscriptions.map {|_id, person, _email| person})
    missing.delete_if {|person| person.asf_member? != true} # remove emeritus

    unless missing.empty?
      _h3_.unsub! 'Not subscribed to the list'
      _p 'Note that members are allowed to unsubscribe if they wish to opt out of receiving notices'
      _table.table do
        _tr_ do
          _th 'id'
          _th 'name'
        end
        missing.sort_by(&:name).each do |person|
          _tr do
            if not ldap.include? person
              _td {_strong.text_danger person.id, title: 'Not in LDAP'}
            else
              _td do
                _a person.id, href: "/roster/committer/#{person.id}"
              end
            end
            if person.public_name
              _td person.public_name
            else
              _td.text_danger '*notinavail*'
            end
          end
        end
      end
      _h3_.unsublist! 'Handy List of Unsubscribed Emails'
      _p do
        missing.each do |person|
          _ "#{person.id}@apache.org, "
        end
      end
    end

    extras = ldap - members

    unless extras.empty?
      _h3_.ldap! 'In LDAP but not in members.txt'
      _table.table do
        _tr_ do
          _th 'id'
          _th 'name'
        end
        extras.sort.each do |person|
          _tr do
            _td do
              _a person.id, href: "/roster/committer/#{person.id}"
            end
            _td person.public_name
          end
        end
      end
    end
    _script %{
      var table = $(".table").stupidtable();
      table.on("aftertablesort", function (event, data) {
        var th = $(this).find("th");
        th.find(".arrow").remove();
        var dir = $.fn.stupidtable.dir;
        var arrow = data.direction === dir.ASC ? "&uarr;" : "&darr;";
        th.eq(data.column).append('<span class="arrow">' + arrow +'</span>');
        });
      }
    end
  end
end
