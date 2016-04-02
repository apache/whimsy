#
# Render and edit a person's SpamAssassin score
#

class PersonSascore < React
  def render
    committer = @@person.state.committer

    _tr data_edit: 'sascore' do
      _td 'SpamAssassin score'

      _td do

        if @edit_sascore

          _form method: 'post' do
            _input type: 'number', min: 0, max: 10, 
              name: 'sascore', defaultValue: committer.sascore
            _input type: 'submit', value: 'submit'
          end

        else

          _span committer.sascore

        end
      end
    end
  end
end
