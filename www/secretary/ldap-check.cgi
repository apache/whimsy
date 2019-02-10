#!/usr/bin/env ruby

=begin

Compare LDAP lists

project.memberids should agree with Group.memberids (if it exixts)
project.ownerids should agree with Committee.memberids (if it exists)

members and owners should also be committers

The two committers groups should have the same members:
- cn=committers,ou=role,ou=groups,dc=apache,dc=org (new role group)
- cn=committers,ou=groups,dc=apache,dc=org (old unix group)

All committers should be in LDAP people
LDAP people whould be committers (unles login is disabled)

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

  _h1 'LDAP membership checks'

  old = ASF::Group['committers'].memberids
  new = ASF::Committer.listids
  people = ASF::Person.preload(%w(uid createTimestamp asf-banned loginShell))

  _h2 'members and owners'

  _p do
    _ 'LDAP project members must agree with corresponding (unix) group members'
    _br
    _ 'LDAP project owners must agree with corresponding committee members'
    _br
    _ 'The table below show the differences, if any'
  end

  _table do
    _tr do
      _th 'Project'
      _th 'project members - group members'
      _th 'group members - project members'
      _th 'project owners - committee members'
      _th 'committee-members - project owners'
      _th 'not in committers group'
    end

    projects = ASF::Project.list
    
    projects.sort_by(&:name).each do |p|
      po_co=[]
      co_po=[]
      pm_um=[]
      um_pm=[]
      notc=[]
      # TODO to be removed soon
      # Use hasLDAP? to check if the underlying ou=pmc group exists
      if c=ASF::Committee[p.name] and c.hasLDAP? # we have PMC group 
        po=p.ownerids
        co=c.memberids
        po_co=po-co
        co_po=co-po
        notc += po.reject {|n| old.include? n}
        notc += co.reject {|n| old.include? n}
      end
      # TODO likewise, only applies to historic groups
      if u=ASF::Group[p.name] # we have the unix group
        pm=p.memberids
        um=u.memberids
        pm_um=pm-um
        um_pm=um-pm
        notc += pm.reject {|n| old.include? n}
        notc += um.reject {|n| old.include? n}
      end
      if pm_um.size > 0 or um_pm.size > 0 or po_co.size > 0 or co_po.size > 0 or notc.size > 0
        _tr do
          _td do
            _a p.name, href: '/roster/committee/' + p.name
          end
          _td do
            pm_um.each do |id|
              _a id, href: '/roster/committer/' + id
            end
          end
          _td do
            um_pm.each do |id|
              _a id, href: '/roster/committer/' + id
            end
          end
          _td do
            po_co.each do |id|
              _a id, href: '/roster/committer/' + id
            end
          end
          _td do
            co_po.each do |id|
              _a id, href: '/roster/committer/' + id
            end
          end
          _td do
            notc.uniq.each do |id|
              _a id, href: '/roster/committer/' + id
              if ASF::Person[id].nologin?
                _ 'NoLogin'
              end
              _br
            end
          end
        end
      end
    end
  end

  _h2 'people who are not committers (excluding nologin)'
  
  non_committers = people.reject { |p| p.nologin? or old.include? p.name or p.name == 'apldaptest'}
  if non_committers.length > 0
    _table do
      _tr do
        _th 'UID'
        _th 'asf-banned?'
        _th 'Date'
        _th 'ICLA'
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
        end
      end
    end
  else
    _p 'All LDAP people entries are committers'
  end

  _h2 'committers who are not in LDAP people'
  
  # which committers are not people?
  non_people = old.reject {|id| people.map(&:name).include? id}
  
  if non_people.length > 0
    _table do
      _tr do
        _th 'uid'
      end
      non_people.sort.each do |id|
        _tr do
          _td do
            _a id, href: '/roster/committer/' + id
          end
        end
      end
    end
  else
    _p 'All committers are included in LDAP people'
  end

  _h2 'Committers'
  _p do
    _ 'There are currently two LDAP committers groups:'
    _br
    _ 'cn=committers,ou=role,ou=groups,dc=apache,dc=org (new role group)'
    _br
    _ 'cn=committers,ou=groups,dc=apache,dc=org (old unix group)'
    _br
    _ 'These should agree'
  end

  new_old = new - old
  old_new = old - new

  if new_old.size > 0
    _p do
      _ 'The following ids are in the new group but not the old'
      _br
      _ new_old.join(',')
    end
  elsif old_new.size == 0
  _p 'The groups are equal'
  end

  if old_new.size > 0
    _p do
      _ 'The following ids are in the old group but not the new'
      _br
      _ old_new.join(',')
    end
  end

end