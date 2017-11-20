#
# Render and edit a person's member status
#

class PersonMemberStatus < Vue
  def render
    committer = @@person.state.committer

    _div.row data_edit: ('memstat' if @@person.props.auth.secretary) do
      _div.name 'Member status'

      if committer.member.status
        _div.value do
          _span committer.member.status

         if @@edit == :memstat
           _form.inline method: 'post' do
             if committer.member.status.include? 'Active'
               _button.btn.btn_primary 'move to emeritus',
                 name: 'action', value: 'emeritus'
             elsif committer.member.status.include? 'Emeritus'
               _button.btn.btn_primary 'move to active',
                 name: 'action', value: 'active'
             end
           end
         end
        end
      end
    end
  end
end
