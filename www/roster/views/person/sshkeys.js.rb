#
# Render and edit a person's SSH keys
#

class PersonSshKeys < React
  def render
    committer = @@person.state.committer

    _tr do
      _td 'SSH keys'


      _td do
        _ul committer.ssh do |key|
          _li.ssh do
            _pre.wide key
          end
        end
      end
    end
  end
end

