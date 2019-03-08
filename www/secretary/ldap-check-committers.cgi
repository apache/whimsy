#!/usr/bin/env ruby

=begin

LDAP people should be committers (unless login is disabled)

=end

$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'whimsy/asf/mlist'
require 'wunderbar'

_html do
  _style %{
    table {border-collapse: collapse}
    table, th, td {border: 1px solid black}
    td {padding: 3px 6px}
    tr:hover td {background-color: #FF8}
    th {background-color: #a0ddf0}
  }

  _h1 'LDAP membership checks'

  old = ASF::Group['committers'].memberids
  people = ASF::Person.preload(%w(uid createTimestamp asf-banned asf-altEmail mail loginShell))

  _h2 'people who are not committers (excluding nologin)'
  
  non_committers = people.reject { |p| p.nologin? or old.include? p.name or p.name == 'apldaptest'}
  if non_committers.length > 0
    _table do
      _tr do
        _th 'UID'
        _th 'asf-banned?'
        _th 'Date'
        _th 'ICLA'
        _th 'Subscriptions'
        _th 'Moderates'
      end
      non_committers.sort_by(&:name).each do |p|
        icla = ASF::ICLA.find_by_id(p.name)
        _tr do
          _td do
            _a p.name, href: '/roster/committer/' + p.name
          end
          _td p.asf_banned?
          _td p.createDate
          if icla
            if icla.claRef
              _td do
                _a icla.claRef, href: "https://svn.apache.org/repos/private/documents/iclas/#{icla.claRef}"
              end
            else
              _td icla.form
            end
          else
            _td 'No ICLA entry found'
          end
          all_mail = p.all_mail
          _td do
            # keep only the list names
            _ ASF::MLIST.subscriptions(all_mail)[:subscriptions].map{|x| x[0]}
          end
          _td do
            _ ASF::MLIST.moderates(all_mail)[:moderates]
          end
        end
      end
    end
  else
    _p 'All LDAP people entries are committers'
  end

end