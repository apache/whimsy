#
# Render and edit a person's SpamAssassin score
#

class PersonSascore < Vue
  def render
    committer = @@person.state.committer

    _div.row data_edit: 'sascore' do
      _div.name 'SpamAssassin score'

      _div.value do

        if @@edit == :sascore

          _form method: 'post' do
            _input type: 'number', min: 0, max: 10,
              name: 'sascore', value: committer.sascore
            _input type: 'submit', value: 'submit'
          end

        else

          _span committer.sascore

        end
      end
    end
  end
end
