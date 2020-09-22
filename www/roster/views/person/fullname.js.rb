#
# Render and edit a person's name
#

class PersonName < Vue
  def render
    committer = @@person.state.committer

    _div.row data_edit: ('fullname' if @@person.props.auth.secretary) do
      _div.name 'Name'

      _div.value do
        name = committer.name

        if @@edit == :fullname

          _form.inline method: 'post' do
            _div do
              _label 'public name', for: 'publicname'
              _input.publicname! name: 'publicname', required: true,
                value: name.public_name
            end

            _div do
              _label 'legal name', for: 'legalname'
              _input.legalname! name: 'legalname', required: true,
                value: name.legal_name
            end

            _div do
              _label 'common name', for: 'commonname'
              _input.commonname! name: 'commonname', required: true,
                value: name.ldap
            end

            _div do
              _label 'given name', for: 'givenname'
              _input.legalname! name: 'givenname', required: true,
                value: name.given_name
            end

            _div do
              _label 'family name', for: 'familyname'
              _input.familyname! name: 'familyname', required: true,
                value: name.family_name
            end

            _button.btn.btn_primary 'submit'
          end

        else

          if
            (not name.legal_name or name.public_name==name.legal_name) and
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
