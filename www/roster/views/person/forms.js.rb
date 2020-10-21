#
# Show a list of a person's forms on file
#

class PersonForms < Vue
  def render
    committer = @@person.state.committer

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
                  _a 'ICLA', href: link
                end
              end
            elsif form == 'member'
              _li do
                if link == '' # has form but no karma to view it
                  _ 'Member App'
                else
                  _a 'Member App',
                    href: link
                end
              end
            elsif form == 'emeritus'
              _li do
                if link == '' # has form but no karma to view it
                  _ 'Emeritus'
                else
                  _a 'Emeritus',
                    href: link
                end
              end
            elsif form == 'emeritus_request'
              _li do
                if link == '' # has form but no karma to view it
                  _ 'Emeritus Request'
                else
                  _a 'Emeritus Request',
                    href: link
                end
                emeritus_request_age = committer['emeritus_request_age']
                if emeritus_request_age
                  _ ' Days since submission: '
                  _ emeritus_request_age
                end
              end
            elsif form == 'emeritus_rescinded'
              _li do
                if link == '' # has form but no karma to view it
                  _ 'Emeritus Rescinded'
                else
                  _a 'Emeritus Rescinded',
                    href: link
                end
              end
            elsif form == 'emeritus_reinstated'
              _li do
                if link == '' # has form but no karma to view it
                  _ 'Emeritus Reinstated'
                else
                  _a 'Emeritus Reinstated',
                    href: link
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
