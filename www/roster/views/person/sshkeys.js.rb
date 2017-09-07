#
# Render and edit a person's SSH keys
#

class PersonSshKeys < Vue
  def render
    committer = @@person.state.committer

    _div.row do
      _div.name 'SSH keys'

      _div.value do
        _ul committer.ssh do |key|
          _li.ssh do
            _pre.wide key
          end
        end
      end
    end
  end
end

