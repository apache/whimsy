#
# Show a list of a person's forms on file
#

class PersonForms < Vue
  def render
    form_names = {
      icla: 'ICLA',
      member: 'Member App',
      emeritus: 'Emeritus',
      emeritus_request: 'Emeritus Request',
      emeritus_rescinded: 'Emeritus Rescinded',
      emeritus_reinstated: 'Emeritus Reinstated',
      withdrawal_request: 'Withdrawal Request',
    }
    committer = @@person.state.committer

    _div.row do
      _div.name 'Forms on file'

      _div.value do
        _ul do
          for form in committer.forms
            link = committer.forms[form]
            link_name = form_names[form] || link_name
            _li do
              if link == '' # has form but no karma to view it
                _ link_name
              else
                _a link_name, href: link
              end
              if form == 'emeritus_request'
                emeritus_request_age = committer['emeritus_request_age']
                if emeritus_request_age
                  _ ' Days since submission: '
                  _ emeritus_request_age
                end
              elsif form == 'withdrawal_request'
                withdrawal_request_age = committer['withdrawal_request_age']
                if withdrawal_request_age
                  _ ' Days since submission: '
                  _ withdrawal_request_age
                end
              end
            end
          end
        end
      end
    end
  end
end
