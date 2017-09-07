#
# Render and edit a person's members.txt entry
#

class PersonMemberText < Vue
  def render
    committer = @@person.state.committer

    _div.row data_edit: 'memtext' do
      _div.name 'Members.txt'

      _div.value do
        if @@edit == :memtext

          _form.inline method: 'post' do
            _div do
              _textarea committer.member.info, name: 'entry'
            end
            _button.btn.btn_primary 'submit'
          end

        else

          _pre committer.member.info,
            class: ('small' if committer.member.info =~ /.{81}/)
        end
      end
    end
  end
end
