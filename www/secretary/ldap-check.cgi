#!/usr/bin/env ruby

=begin

Compare LDAP lists (also CI)

PMC members should be the same as project owners (for actual PMCs)
owners should also be members
members and owners should also be committers

The two committers groups should have the same members:
- cn=committers,ou=role,ou=groups,dc=apache,dc=org (new role group)
- cn=committers,ou=groups,dc=apache,dc=org (old unix group)

All committers should be in LDAP people
LDAP people would be committers (unless login is disabled)

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
  new = ASF::Committer.listids
  people = ASF::Person.preload(%w(uid createTimestamp asf-banned asf-altEmail mail loginShell))

  # fetch the email details up front to avoid rescanning
  modded = Hash.new{ |h,k| h[k] = Array.new}
  ASF::MLIST.list_parse('mod') do |dom,list,mods|
    mods.each {|mod| modded[mod] << [list,dom].join('@')}
  end

  subbed = Hash.new{ |h,k| h[k] = Array.new}
  ASF::MLIST.list_parse('sub') do |dom,list,subs|
    subs.each {|sub| subbed[sub] << [list,dom].join('@')}
  end

  _h2 'members and owners'

  _p do
    _ 'PMC members should be project owners and vice-versa'
    _br
    _ 'LDAP project owners should also be project members'
    _br
    _ 'project/podling committers must be in committers group'
    _br
    _ 'The table below show the differences, if any'
  end

  projects = ASF::Project.preload # for performance
  pmcs = ASF::Committee.pmcs

  _table do
    _tr do
      _th 'Project'
      _th 'PMC member but not project owner'
      _th 'Project owner but not PMC member'
      _th 'Project owner but not project member'
      _th 'in project (owner or member) but not in committers group'
    end

    projects.keys.sort_by(&:name).each do |p|
      po=p.ownerids
      pm=p.memberids
      po_pm = po - pm
      cttee = ASF::Committee.find(p.name)
      # Is this a real PMC?
      if pmcs.include? cttee
        isPMC = true
        cm = cttee.roster.keys
        cm_po = cm - po
        po_cm = po - cm
      else
        isPMC = false
        cm_po = []
        po_cm = []
      end
      notc=[]
      notc += po.reject {|n| old.include? n}
      notc += pm.reject {|n| old.include? n}
      if po_pm.size > 0 or cm_po.size > 0 or po_cm.size > 0 or notc.size > 0
        _tr do
          _td do
            if isPMC
              _a p.name, href: '/roster/committee/' + p.name
            else
              _a p.name, href: '/roster/ppmc/' + p.name
            end
          end
          _td do
            cm_po.each do |id|
              _a id, href: '/roster/committer/' + id
            end
          end
          _td do
            po_cm.each do |id|
              _a id, href: '/roster/committer/' + id
            end
          end
          _td do
            po_pm.each do |id|
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
                _a icla.claRef, href: ASF::SVN.svnpath!('iclas', ASF::ICLAFiles.match_claRef(icla.claRef))
              end
            else
              _td icla.form
            end
          else
            _td 'No ICLA entry found'
          end
          all_mail = p.all_mail
          _td do
            _ subbed.select{|k| all_mail.include? k }.map{|k,v| v}.flatten
          end
          _td do
            _ modded.select{|k| all_mail.include? k }.map{|k,v| v}.flatten
          end
        end
      end
    end
  else
    _p 'All LDAP people entries are committers'
  end

  _h2 'People who are banned or have nologin but are still committers'

  people_projects=Hash.new{|h,k| h[k]=Array.new}

  projects.keys.each do |prj|
    prj.members.each do |m|
      people_projects[m] << prj.name
    end
    prj.owners.each do |m|
      people_projects[m] << prj.name+'-(p)pmc'
    end
  end

  _table do
    _tr do
          _th 'UID'
          _th 'Created'
          _th 'asf-banned?'
          _th 'Login'
          _th 'Projects (if any)'
    end
    people.select {|p| p.inactive? and new.include? p.name}.sort_by(&:name).each do |p|
      _tr do
        _td do
          _a p.name, href: '/roster/committer/' + p.name
        end
        _td p.createDate
        _td p.asf_banned?
        _td p.loginShell
        _td people_projects[p.name].join(',')
      end
    end
  end

  _h2 'People who have nologin set but are not banned'

  _table do
    _tr do
          _th 'UID'
          _th 'Created'
          _th 'Login'
    end
    people.select {|p| p.inactive? and not p.asf_banned?}.sort_by(&:name).each do |p|
      _tr do
        _td do
          _a p.name, href: '/roster/committer/' + p.name
        end
        _td p.createDate
        _td p.loginShell
      end
    end
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
      _ new_old.map{|x| x.inspect}.join(',')
    end
  elsif old_new.size == 0
  _p 'The groups are equal'
  end

  if old_new.size > 0
    _p do
      _ 'The following ids are in the old group but not the new'
      _br
      _ old_new.map{|x| x.inspect}.join(',')
    end
  end

end