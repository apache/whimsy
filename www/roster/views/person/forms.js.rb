#
# Show a list of a person's forms on file
#

class PersonForms < Vue
  def render
    committer = @@person.state.committer
    documents = "https://svn.apache.org/repos/private/documents"

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
                  _a 'ICLA', href: "#{documents}/iclas/#{link}"
                end
              end
            elsif form == 'member'
              _li do
                if link == '' # has form but no karma to view it
                  _ 'Membership App'
                else
                  _a 'Membership App',
                    href: "#{documents}/member_apps/#{link}"
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
