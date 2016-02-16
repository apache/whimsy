#
# A single committer
#

_html do
  _title 'ASF Member list'
  _link rel: 'stylesheet', href: 'stylesheets/app.css'

  _banner breadcrumbs: {
    roster: '.',
    members: 'members'
  }

  members = ASF::Member.list.dup

  # ********************************************************************
  # *                             Summary                              *
  # ********************************************************************

  _h1_ 'Summary'

  summary = ASF::Member.status

  _table.counts do
    _tr do
      _td((members.keys - summary.keys).length)
      _td 'Active members'
    end

    summary.group_by(&:last).each do |category, list|
      _tr do
        _td list.count
        _td category + 's'
      end
    end
  end

  # ********************************************************************
  # *                         Merge LDAP info                          *
  # ********************************************************************

  # merge ldap info, preferring public names over name listed in members.txt
  ldap = ASF.members
  preload = ASF::Person.preload('cn', ldap)

  ldap.each do |person|
    if members[person.id]
      members[person.id][:name] = person.cn
    else
      members[person.id] = {name: person.cn, issue: 'not in members.txt'}
    end
  end

  # ********************************************************************
  # *                          Complete list                           *
  # ********************************************************************

  _h1_ 'Members'

  _table.table.table_hover do
    _thead do
      _tr do
        _th 'id'
        _th 'public name'
        _th 'status'
      end
    end

    members.sort_by {|id, info| info[:name]}.each do |id, info|
      _tr_ do
        _td! do
          if ldap.include? ASF::Person.find(id)
            _b {_a id, href: "committer/#{id}"}
          else
            _a id, href: "committer/#{id}"
            
            info[:issue] ||= 'Not in LDAP' if not info['status']
          end
        end

        _td info[:name]

        if info[:issue]
          _td.issue info[:issue]
        elsif
          _td info['status']
        end
      end
    end
  end

end
