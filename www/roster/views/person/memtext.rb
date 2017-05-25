#
# Render and edit a person's members.txt entry
#

class PersonMemberText < React
  def render
    committer = @@person.state.committer

    _div.row data_edit: 'memtext' do
      _div.name 'Members.txt'

      _div.value do
        if @@person.state.edit_memtext

          _form.inline method: 'post' do
            _div do
              _textarea name: 'entry', defaultValue: committer.member.info
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
