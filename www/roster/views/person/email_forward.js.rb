#
# Render and edit a person's forward E-mail addresses
#

class PersonEmailForwards < Vue
  def render
    committer = @@person.state.committer

    _div.row data_edit: 'email_forward' do
      _div.name 'Email forwarded to'

      _div.value do

        if @@edit == :email_forward

          _form method: 'post' do
            current = 1
            prefix = 'email_forward' # must agree with email_forward.json.rb
            _input type: 'hidden', name: 'array_prefix', value: prefix

            _div committer.email_forward do |key|
              _input name: prefix + current, value: key, size: 30
              _br
              current += 1
            end
            # Spare field to allow new entry to be added
            _input name: prefix + current, placeholder: '<forwarding email>', size: 30
            _br

            _input type: 'submit', value: 'submit'
          end

        else

          _ul committer.email_forward do |mail|
            _li do
              _a mail, href: 'mailto:' + mail
            end
          end
        end
      end
    end
  end
end
