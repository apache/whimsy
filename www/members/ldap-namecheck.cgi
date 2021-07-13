#!/usr/bin/env ruby
PAGETITLE = "Crosscheck LDAP Names With Public Name from ICLAs"  # Wvisible:members
$LOAD_PATH.unshift '/srv/whimsy/lib'

# Check LDAP names: cn, sn, givenName
#
# givenName and sn should match the output from ASF::Person.ldap_name


require 'whimsy/asf'
require 'wunderbar/script'
require 'ruby2js/filter/functions'

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
    _ 'LDAP sn and givenName must match the result of ASF::Person.ldap_name; cn should match Public Name'
    _br
    _ 'The table below show the differences, if any.'
    _br
    _ 'If the cn does not match the public name, the cell is light grey'
    _br
    _ 'If the givenName or sn does not match part or all of the public name, the cell is light grey'
    _br
    _ 'If the Public Name has only a single word, givenName is marked as strike-thru as it should perhaps be dropped'
    _br
    _ 'The Modify? columns show suggested fixes. If the name is non-italic then the suggestion is likely correct; italicised suggestions may be wrong/unnecessary.'
    _br
    _ 'The suggested name is considered correct if:'
    _ul do
      _li 'The existing field value matches the uid (never initialised) or the cn (single name)'
      _li 'The existing field is missing'
      _li 'AND there are no parts of the cn unused'
    end
  end

  # prefetch LDAP data
  people = ASF::Person.preload(%w(uid cn sn givenName loginShell))
  matches = 0
  mismatches = 0
  badGiven = 0
  badSN = 0

  # prefetch ICLA data
  ASF::ICLA.preload

  _table do
    # Must agree with columnNames below
    _tr do
      _th 'uid'
      _th "iclas.txt public name"
      _th 'cn'
      _th 'givenName'
      _th 'Modify to?'
      _th 'sn'
      _th 'Modify to?'
      _th 'Unused names'
    end

    people.sort_by(&:name).each do |p|
      next if p.banned?
      next if p.name == 'apldaptest'

      given = p.givenName rescue '' # some entries have not set this up

      parse = ASF::Person.ldap_name(p.cn)
      new_given = parse['givenName'] || ''
      new_sn = parse['sn']
      unused = parse['unused']
      _initials = parse['initials']

      givenOK = ASF::Person.names_equivalent?(new_given, given)
      badGiven += 1 unless givenOK

      snOK =    (new_sn == p.sn)
      badSN += 1 unless snOK

      icla = ASF::ICLA.find_by_id(p.uid)
      public_name = icla.name rescue nil
      next unless public_name # Don't check entries not in iclas.txt

      cnOK = (public_name == p.cn)
      pnames=public_name.gsub(%r{[(),]}, '').split # drop special characters that may terminate names
      missingGiven = given.split.any? {|one| ! (one == p.uid or pnames.include?(one) or pnames.any? {|pn| ASF::Person.names_equivalent?(pn, one)})}
      missingsn = p.sn.split.any? {|one| ! (one == p.uid or pnames.include? one or pnames.any? {|pn| ASF::Person.names_equivalent?(pn, one)})}
      if givenOK and snOK and cnOK and ! missingGiven and ! missingsn # all checks OK
        matches += 1
        next
      end

      if 0 == (mismatches += 1) % 30 # repeat header every 30 lines
        _tr bgcolor: 'lightblue' do
          _td 'uid'
          _td "iclas.txt public name"
          _td 'cn'
          _td 'givenName'
          _td 'Modify to?'
          _td 'sn'
          _td 'Modify to?'
          _td 'Unused names'
        end
      end

      _tr do
        _td do
          _a p.uid, href: '/roster/committer/' + p.uid
        end
        _td public_name
        if p.cn == public_name
          _td p.cn
        else
          _td bgcolor: 'lightgrey' do
            _ p.cn
          end
        end
        _td bgcolor: missingGiven ? 'lightgrey' : 'white' do
          if givenOK
            _ given
          elsif new_given == ''
            _del given # entry should be removed
          else
            _em given
          end
        end
        _td! copyAble: 'true' do
          if givenOK
            _ ''
          else
              if unused.size == 0 and (given == p.uid or given == '---' or given == p.cn)
                _ new_given # likely to be correct
              else
                _em new_given # less likely
              end
          end
        end
        _td bgcolor: missingsn ? 'lightgrey' : 'white' do
          if snOK
            _ p.sn
          else
            _em p.sn
          end
        end
        _td! copyAble: 'true' do
          if snOK
            _ ''
          else
            if unused.size == 0 and (p.sn == p.uid or p.sn == p.cn)
              _ new_sn
            else
              _em new_sn
            end
          end
        end
        _td unused.join(' ')
      end
    end
    _tr bgcolor: 'lightblue' do
      _td 'uid'
      _td "iclas.txt public name"
      _td 'cn'
      _td 'givenName'
      _td 'Modify to?'
      _td 'sn'
      _td 'Modify to?'
      _td 'Unused names'
    end
  end

  _p do
    _ "Total: #{people.size} Matches: #{matches} GivenBad: #{badGiven} SNBad: #{badSN}"
  end

end
