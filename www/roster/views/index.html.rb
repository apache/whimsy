#
# Landing page
#
PAGETITLE = "ASF Roster Tool" # Wvisible:projects

_html do
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"

  _body? do
    if @stamps
      _.comment! "TIMES %s TIMES" % @stamps.join(',')
    end
    _whimsy_body(
      title: PAGETITLE,
      breadcrumbs: {
        roster: '.'
      }
    ) do
      person = ASF::Person.find(env.user)
      _table.counts do

        _tr do
          _td do
            _a '1', href: 'committer/__self__'
          end
          _td do
            _a env.user, href: 'committer/__self__'
          end
          _td 'Your personal page'
        end

        ### committers

        _tr do
          _td do
            _a @committers.length, href: 'committer/'
          end

          _td do
            _a 'Committers', href: 'committer/'
          end

          _td do
            _ 'Search for committers by name, user id, or email address'
            _ ' (includes '
            _ @committers.select{|c| c.inactive?}.length
            _ ' inactive accounts)'
          end
        end

        if person.asf_member? or ASF.pmc_chairs.include? person
          _tr do
            _td do
              _a @committers.length, href: 'committer2/'
            end

            _td do
              _a 'Committers', href: 'committer2/'
            end

            _td do
              _ 'Search for committers by name, user id, or email address.'
              _ ' Also includes pending ICLAs'
            end
          end
        end

        ### members

        _tr do
          _td do
            _a @members.length, href: 'members'
          end

          _td do
            _a 'Members', href: 'members'
          end

          _td 'Active ASF members'
        end

        ### PMCs

        _tr do
          _td do
            _a @committees.length, href: 'committee/'
          end

          _td do
            _a 'PMCs', href: 'committee/'
          end

          _td 'Active projects at the ASF'
        end

        _tr do
          _td do
            _a @nonpmcs.length, href: 'nonpmc/'
          end

          _td do
            _a 'nonPMCs', href: 'nonpmc/'
          end

          _td 'ASF Committees (non-PMC)'
        end

        ### Podlings

        _tr do
          _td do
            _a @podlings.select {|podling| podling.status == 'current'}.length,
              href: 'ppmc/'
          end

          _td do
            _a 'Podlings', href: 'ppmc/'
          end

          _td! do
            _span 'Active podlings at the ASF ('
            _a @podlings.length, href: 'podlings'
            _span ' total)'
          end

        end

        _tr do
          _td do
            _a @petri.length, href: 'petri'
          end

          _td do
            _a 'Petri', href: 'petri'
          end

          _td 'Petri cultures'
        end

        # LDAP project groups without a PMC or active podling etc
        _tr do
          _td do
            _a @otherids.length, href: 'other/'
          end

          _td do
            _a 'Other', href: 'other/'
          end

          _td 'LDAP project groups with no apparent committee or podling'
        end

        ### Groups

        _tr do
          _td do
            _a @groups.length, href: 'group/'
          end

          _td do
            _a 'Groups', href: 'group/'
          end

          _td 'Assorted other groups from various sources'
        end

      end

      if person.asf_member? or ASF.pmc_chairs.include? person
        _hr
        _p do
          _a 'Search pending ICLAs', href: 'icla/'
          _span.glyphicon.glyphicon_lock :aria_hidden, class: "text-primary", aria_label: "ASF Members and Officers",
                                                                                   title: "ASF Members and Officers"
        end
        _p do
          _a 'Organization Chart ', href: 'orgchart/'
          _span.glyphicon.glyphicon_lock :aria_hidden, class: "text-primary", aria_label: "ASF Members and Officers",
                                                                                   title: "ASF Members and Officers"
        end
      end
    end
  end
end
