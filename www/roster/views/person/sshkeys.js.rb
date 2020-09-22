#
# Render and edit a person's SSH keys
#

class PersonSshKeys < Vue
  def render
    committer = @@person.state.committer

    _div.row data_edit: 'sshkeys' do
      _div.name 'SSH keys'

      _div.value do

        if @@edit == :sshkeys

          _form method: 'post' do
            current = 1
            prefix = 'sshkeys' # must agree with sshkeys.json.rb
            _input type: 'hidden', name: 'array_prefix', value: prefix

            _div committer.ssh do |key|
              _input style: 'font-family:Monospace', size: 100, name: prefix + current, value: key
              _br
              current += 1
            end
            # Spare field to allow new entry to be added
            _input style: 'font-family:Monospace', size: 100, name: prefix + current, placeholder: '<enter a new ssh key>'
            _br

            _input type: 'submit', value: 'submit'
          end

        else
          if committer.ssh.empty?
            _ul do
              _li '(none defined)'
            end
          else
            _ul committer.ssh do |key|
              _li.ssh do
                _pre.wide key
              end
            end
          end
        end
      end
    end
  end
end

