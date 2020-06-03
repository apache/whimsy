#
# Show a list of a person's forms on file
#

class PersonForms < Vue
  def render
    committer = @@person.state.committer
    icla_url = ASF::SVN.svnurl('icla')
    member_apps_url = ASF::SVN.svnurl('member_apps')
    emeritus_url = ASF::SVN.svnurl('emeritus')
    rescinded_url = ASF::SVN.svnurl('emeritus-rescinded')
    reinstated_url = ASF::SVN.svnurl('emeritus-reinstated')
    requested_url = ASF::SVN.svnurl('emeritus-requests-received')

    console.log "emeritus #{emeritus_url}"

    _div.row do
      _div.name 'Forms on file'

      _div.value do
        _ul do
          for form in committer.forms
            link = committer.forms[form]
            
            if form == 'icla'
              _li do
                if link == '' # has ICLA bu no karma to view it
                  _ 'ICLA'
                else
                  _a 'ICLA', href: "#{icla_url}/#{link}"
                end
              end
            elsif form == 'member'
              _li do
                if link == '' # has form but no karma to view it
                  _ 'Member App'
                else
                  _a 'Member App',
                    href: "#{member_apps_url}/#{link}"
                end
              end
            elsif form == 'emeritus'
              _li do
                if link == '' # has form but no karma to view it
                  _ 'Emeritus'
                else
                  _a 'Emeritus',
                    href: "#{emeritus_url}/#{link}"
                end
              end
            elsif form == 'emeritus_request'
              _li do
                if link == '' # has form but no karma to view it
                  _ 'Emeritus Request'
                else
                  _a 'Emeritus Request',
                    href: "#{requested_url}/#{link}"
                end
              end
            elsif form == 'emeritus_requests_rescinded'
              _li do
                if link == '' # has form but no karma to view it
                  _ 'Emeritus Rescinded'
                else
                  _a 'Emeritus Rescinded',
                    href: "#{rescinded_url}/#{link}"
                end
              end
            elsif form == 'emeritus_reinstated'
              _li do
                if link == '' # has form but no karma to view it
                  _ 'Emeritus Reinstated'
                else
                  _a 'Emeritus Reinstated',
                    href: "#{reinstated_url}/#{link}"
                end
              end
            else
              _li "#{form}: #{link}"
            end
          end
        end
      end
    end
  end
end
