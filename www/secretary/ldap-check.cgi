#!/usr/bin/env ruby

=begin

Compare LDAP lists

project.memberids should agree with Group.memberids (if it exixts)
project.ownerids should agree with Committee.memberids (if it exists)
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
      _th 'GuineaPig?'
      _th 'project members - group members'
      _th 'group members - project members'
      _th 'project owners - committee members'
      _th 'committee-members - project owners'
    end

    projects = ASF::Project.list
    
    projects.sort_by(&:name).each do |p|
      po_co=[]
      co_po=[]
      pm_um=[]
      um_pm=[]
      if c=ASF::Committee[p.name] # we have PMC 
        po=p.ownerids
        co=c.ownerids
        po_co=po-co
        co_po=co-po
      end
      if u=ASF::Group[p.name] # we have the unix group
        pm=p.memberids
        um=u.memberids
        pm_um=pm-um
        um_pm=um-pm
      end
      if pm_um.size > 0 or um_pm.size > 0 or po_co.size > 0 or co_po.size > 0
        _tr do
          _td do
            _a p.name, href: '/roster/committee/' + p.name
          end
          _td ASF::Committee.isGuineaPig?(p.name)
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
        end
      end
    end
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

  old = ASF::Group['committers'].memberids
  new = ASF::Committer.listids

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