#!/usr/bin/env ruby

=begin

Check LDAP names: cn, sn, givenName

Both givenName and sn should match part of cn

=end

$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar'

_html do
  _style %{
    table {border-collapse: collapse}
    table, th, td {border: 1px solid black}
    td {padding: 3px 6px}
    tr:hover td {background-color: #FF8}
    th {background-color: #a0ddf0}
  }

  _h1 'LDAP people name checks'

  _p do
    _ 'LDAP sn and givenName must match part of cn'
    _br
    _ 'The table below show the differences, if any'
  end

  # prefetch LDAP data
  people = ASF::Person.preload(%w(uid cn sn givenName))
  matches = 0
  badGiven = 0

  _table do
    _tr do
      _th 'uid'
      _th 'cn'
      _th 'givenName'
      _th 'sn'
    end

    people.sort_by(&:name).each do |p|
      given = p.givenName rescue '---' # some entries have not set this up
      givenOK = p.cn.include? given
      badGiven += 1 unless givenOK
      snOK = p.cn.include? p.sn
      if givenOK and snOK
        matches += 1
        next
      end
      _tr do
        _td do
          _a p.uid, href: '/roster/committee/' + p.uid
        end
        _td do
          _ p.cn
        end
        _td do
          if givenOK
            _ given
          else
            _em given
          end
        end
        _td do
          if snOK
            _ p.sn
          else
            _em p.sn
          end
        end
      end
    end
  end

  _p do
    _ "Total: #{people.size} Matches: #{matches} GivenBad: #{badGiven}"
  end
end