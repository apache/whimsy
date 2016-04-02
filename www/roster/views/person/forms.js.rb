#
# Show a list of a person's forms on file
#

class PersonForms < React
  def render
    committer = @@person.state.committer
    documents = "https://svn.apache.org/repos/private/documents"

    _tr do
      _td 'Forms on file'

      _td do
        _ul do
          for form in committer.forms
            link = committer.forms[form]
            
            if form == 'icla'
              _li do
                _a 'ICLA', href: "#{documents}/iclas/#{link}"
              end
            elsif form == 'member'
              _li do
                _a 'Membership App', 
                  href: "#{documents}/member_apps/#{link}"
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
