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
    _ 'The table below show the differences, if any.'
    _br
    _ 'The Modify? columns show suggested fixes. If the name is non-italic then the suggestion is likely correct; italicised suggestions may be wrong/unnecessary.'
  end

  skipSN = ARGV.shift == 'skipSN' # skip entries with only bad SN

  # prefetch LDAP data
  people = ASF::Person.preload(%w(uid cn sn givenName loginShell))
  matches = 0
  badGiven = 0
  badSN = 0

  # prefetch ICLA data
  ASF::ICLA.preload

  _table do
    _tr do
      _th 'uid'
      _th "ICLA file"
      _th "iclas.txt real name"
      _th "iclas.txt public name"
      _th 'cn'
      _th 'givenName'
      _th 'Modify?'
      _th 'sn'
      _th 'Modify?'
    end

    people.sort_by(&:name).each do |p|
      next if p.banned?
      given = p.givenName rescue '---' # some entries have not set this up

      givenOK = p.cn.include? given
      badGiven += 1 unless givenOK

      snOK = p.cn.include? p.sn
      badSN += 1 unless snOK

      if givenOK and snOK # all checks OK
        matches += 1
        next
      end
      next if givenOK and skipSN

      new_given = '???'
      new_sn = '???'
      names = p.cn.split(' ')
      if names.size == 2
        new_given = names[0]
        new_sn = names[1]
      elsif names.size == 4
        if names[1..2] == %w(de la)
          new_given = names.shift
          new_sn = names.join(' ')
        end
      end
      icla = ASF::ICLA.find_by_id(p.uid)
      claRef = icla.claRef if icla
      claRef ||= 'unknown'
      _tr do
        _td do
          _a p.uid, href: '/roster/committer/' + p.uid
        end
        _td do
          file = ASF::ICLAFiles.match_claRef(claRef.untaint)
          if file
            _a claRef, href: "https://svn.apache.org/repos/private/documents/iclas/#{file}"
          else
            _ claRef
          end
        end
        _td (icla.legal_name rescue '?')
        _td (icla.name rescue '?')
        _td p.cn
        _td do
          if givenOK
            _ given
          else
            _em given
          end
        end
        _td do
          if givenOK
            _ ''
          else
              if given == p.uid or given == '---'
                _ new_given # likely to be correct
              else
                _em new_given # less likely
              end
          end
        end
        _td do
          if snOK
            _ p.sn
          else
            _em p.sn
          end
        end
        _td do
          if snOK
            _ ''
          else
            if p.sn == p.uid
              _ new_sn
            else
              _em new_sn
            end
          end
        end
      end
    end
  end

  _p do
    _ "Total: #{people.size} Matches: #{matches} GivenBad: #{badGiven} SNBad: #{badSN}"
  end
end