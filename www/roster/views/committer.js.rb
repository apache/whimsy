class Committer < React
  def render
    committer = @@committer

    _h2 "#{committer.id}@apache.org"

    _table.wide do

      _tr do
        _td 'Name'
        _td do
          name = committer.name

          if name.public_name==name.legal_name and name.public_name==name.ldap
            _span committer.name.public_name
          else
            _ul do
              _li "#{committer.name.public_name} (public name)"

              if name.legal_name and name.legal_name != name.public_name
                _li "#{committer.name.legal_name} (legal name)"
              end

              if name.ldap and name.ldap != name.public_name
                _li "#{committer.name.ldap} (ldap)"
              end
            end
          end
        end
      end

      if committer.urls
        _tr do
          _td 'Personal URL'
          _td do
            _ul committer.urls do |url|
              _a url, href: url
            end
          end
        end
      end

      unless committer.committees.empty?
        _tr do
          _td 'Committees'
          _td do
            _ul committer.committees do |pmc|
              _li {_a pmc, href: "committee/#{pmc}"}
            end
          end
        end
      end

      unless committer.committer.all? {|pmc| committer.committees.include? pmc}
        _tr do
          _td 'Committer'
          _td do
            _ul committer.committer do |pmc|
              next if committer.committees.include? pmc
              _li {_a pmc, href: "committee/#{pmc}"}
            end
          end
        end
      end

      unless committer.groups.empty?
        _tr do
          _td 'Groups'
          _td do
            _ul committer.groups do |group|
              if group == 'committers'
                _li {_a group, href: "committer/"}
              elsif group == 'member'
                _li {_a group, href: "members"}
              else
                _li {_a group, href: "group/#{group}"}
              end
            end
          end
        end
      end

      if committer.mail
        _tr do
          _td 'Email addresses'
          _td do
            _ul committer.mail do |url|
              _li do
                _a url, href: 'mailto:' + url
              end
            end
          end
        end
      end

      if committer.githubUsername
        _tr do
          _td 'GitHub username'
          _td do
            _a committer.githubUsername, href: 
              "https://github.com/" + committer.githubUsername
          end
        end
      end

      if committer.member
        if committer.member.status
          _tr do
            _td 'Member status'
            _td committer.member.status
          end
        end

        if committer.member.info
          _tr do
            _td 'Members.txt'
            _td {_pre committer.member.info}
          end
        end

        if committer.member.nomination
          _tr do
            _td 'nomination'
            _td {_pre committer.member.nomination}
          end
        end
      end
    end
  end
end
