#
# Render and edit a person's name
#

class PersonName < React
  def render
    committer = @@person.state.committer

    _tr data_edit: ('fullname' if @@person.props.auth.secretary) do
      _td 'Name'

      _td do
        name = committer.name

        if @@person.state.edit_fullname

          _form.inline method: 'post' do
            _div do
              _label 'public name', for: 'publicname'
              _input.publicname! name: 'publicname', required: true,
                defaultValue: name.public_name
            end

            _div do
              _label 'legal name', for: 'legalname'
              _input.legalname! name: 'legalname', required: true,
                defaultValue: name.legal_name
            end

            _button.btn.btn_primary 'submit'
          end

        else

          if 
            name.public_name==name.legal_name and 
            name.public_name==name.ldap
          then
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
    end
  end
end
