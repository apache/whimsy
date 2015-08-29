#!/usr/bin/ruby1.9.1

require 'whimsy/asf'
require 'wunderbar'

user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user or $USER=='ea'
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

ASF::Person.preload('cn')
ASF::ICLA.preload

_html do
  _h1 "public names: LDAP vs ICLA.txt"

  _h2!.present! do
    _ 'Present in '
    _a 'icla.txt', 
      href: 'https://svn.apache.org/repos/private/foundation/officers/iclas.txt'
   _ ':'
  end

  _table_ do
    _tr do
      _th "availid"
      _th "icla.txt real name"
      _th "icla.txt public name"
      _th "LDAP cn"
    end

    ASF::ICLA.new.each do |id, legal_name, name, email|
      next if id == 'notinavail'
      person = ASF::Person.find(id)

      if person.attrs['cn'] 
        cn = person.attrs['cn'].first.force_encoding('utf-8')
      else
        cn = nil
      end

      if cn != name
        _tr_ do
          _td do
            _a id, href: "https://whimsy.apache.org/roster/committer/#{id}"
          end
          _td legal_name
          _td name
          _td cn
        end
      end
    end
  end

  icla = ASF::ICLA.availids
  ldap = ASF::Person.list.sort_by(&:name)
  ldap.delete ASF::Person.new('apldaptest')

  unless ldap.all? {|person| icla.include? person.id}
    _h2.missing! 'Only in LDAP'

    _table do
      _tr do
        _th 'id'
        _th 'cn'
        _th 'mail'
      end

      ldap.each do |person|
        next if icla.include? person.id
        cn = person.attrs['cn'].first
        cn.force_encoding 'utf-8' if cn

        mail = person.attrs['mail'].first
        mail.force_encoding 'utf-8' if mail

        _tr do
          _td do
            _a person.id, href:
              "https://whimsy.apache.org/roster/committer/#{person.id}"
          end
          _td cn
          _td mail
        end
      end
    end
  end
end
