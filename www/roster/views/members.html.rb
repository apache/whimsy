#
# ASF Member List
#

_html do
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"

  _body? do
    _whimsy_body(
      title: 'ASF Member List',
      breadcrumbs: {
        roster: '.',
        members: 'members'
      }
    ) do
      members = ASF::Member.list.dup
      # ********************************************************************
      # *                             Summary                              *
      # ********************************************************************
      summary = ASF::Member.status
      _whimsy_panel_table(
        title: 'Summary - Counts of Members',
        helpblock: -> {
          _ 'Note: while the total count of members is public data, detail
          pages about individual members is '
          _span.glyphicon.glyphicon_lock :aria_hidden, class: 'text-primary', aria_label: 'ASF Members Private'
          _ ' private to the ASF.'
        }
      ) do
        _table.table.counts.members do
          _tr do
            _td((members.keys - summary.keys).length)
            _td 'Active Members'
          end

          summary.group_by(&:last).each do |category, list|
            _tr do
              _td list.count
              _td category + 's'
            end
          end
        end
      end

      # ********************************************************************
      # *                         Merge LDAP info                          *
      # ********************************************************************

      # merge ldap info, preferring public names over name listed in members.txt
      ldap = ASF.members
      _preload = ASF::Person.preload('cn', ldap)

      ldap.each do |person|
        if members[person.id]
          members[person.id][:name] = person.cn
        else
          members[person.id] = {name: person.cn, issue: 'Not in members.txt'}
        end
      end

      # ********************************************************************
      # *                          Complete list                           *
      # ********************************************************************
      _whimsy_panel_table(
        title: 'Member Listing',
        helpblock: -> {
          _ 'Click on column headers to sort; click on ID for '
          _span.glyphicon.glyphicon_lock :aria_hidden, class: 'text-primary', aria_label: 'ASF Members Private'
          _' detail page.'
        }
      ) do
        _table.table.table_hover id: "members" do
          _thead do
            _tr do
              _th 'Id', data_sort: 'string'
              _th.sorting_asc 'Public name', data_sort: 'string'
              _th 'Status', data_sort: 'string'
            end
          end

          _tbody do
            members.sort_by {|_id, info| info[:name]}.each do |id, info|
              _tr_ do
                _td! do
                  if ldap.include? ASF::Person.find(id)
                    _b {_a id, href: "committer/#{id}"}
                  else
                    _a id, href: "committer/#{id}"

                    info[:issue] ||= 'Not in LDAP "member" group' unless info['status']
                  end
                end

                _td info[:name]

                if info[:issue]
                  _td.issue info[:issue]
                else
                  _td info['status']
                end
              end
            end
          end
        end
      end
    end

    _script %{
      $("#members").stupidtable();
    }
  end
end
