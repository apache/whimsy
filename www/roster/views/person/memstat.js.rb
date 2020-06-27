#
# Render and edit a person's member status
#

class PersonMemberStatus < Vue
  def render
    committer = @@person.state.committer
    owner = @@person.props.auth.id == committer.id
                console.log('memstat.js.rb render committer.id: ' + committer.id)
                console.log('memstat.js.rb render @@person.props.auth.id: ' + @@person.props.auth.id)
                console.log('memstat.js.rb render owner? ' + owner)
                console.log('memstat.js.rb render @@person.props.auth.secretary: ' + @@person.props.auth.secretary)
    _div.row data_edit: ('memstat' if @@person.props.auth.secretary or owner) do
      _div.name 'Member status'

      if committer.member.status
        _div.value do
          _span committer.member.status

          if @@edit == :memstat
            opt = { year: 'numeric', month: 'long' } # Suggested date
            dod = Date.new.toLocaleDateString('en-US', opt)
            _form.inline method: 'post' do
              # Cancel this form (implemented in main.js.rb submit(event)
              _button.btn.btn_secondary 'Cancel', data_cancel_submit:true

              # These actions are only for the person's own use
              if owner
                if committer.member.status.include? 'Active'
                  if committer.forms['emeritus_request']
                    emeritus_file_name = committer.forms['emeritus_request']
                    _button.btn.btn_primary 'rescind emeritus request',
                      data_emeritus_file_name:emeritus_file_name,
                      name: 'action', value: 'rescind_emeritus'
                  else
                    _button.btn.btn_primary 'request emeritus status',
                      data_emeritus_person_name:@@person.public_name,
                      name: 'action', value: 'request_emeritus'
                  end
                elsif committer.member.status.include? 'Emeritus'
                  _button.btn.btn_primary 'request reinstatement',
                    name: 'action', value: 'request_reinstatement'
                end
              end
              # These actions are only for secretary's use
              if @@person.props.auth.secretary
                console.log('memstat edit menu secretary...')
                if committer.member.status.include? 'Active'
                  emeritus_file_name = committer.forms['emeritus_request']
                  _button.btn.btn_primary 'move to emeritus',
                    data_emeritus_file_name:emeritus_file_name,
                    name: 'action', value: 'emeritus'
                  _button.btn.btn_primary 'move to deceased',
                    name: 'action', value: 'deceased'
                  _input 'dod', name: 'dod', value: dod
                elsif committer.member.status.include? 'Emeritus'
                  emeritus_file_name = committer.forms['emeritus']
                  _button.btn.btn_primary 'move to active',
                    data_emeritus_file_name:emeritus_file_name,
                    name: 'action', value: 'active'
                  _button.btn.btn_primary 'move to deceased',
                    name: 'action', value: 'deceased'
                  _input 'dod', name: 'dod', value: dod
                elsif committer.member.status.include? 'Deceased'
                  _button.btn.btn_primary 'move to active',
                    name: 'action', value: 'active'
                  _button.btn.btn_primary 'move to emeritus',
                    name: 'action', value: 'emeritus'
                end
              end
            end
          end
        end
      end
    end
  end
end
