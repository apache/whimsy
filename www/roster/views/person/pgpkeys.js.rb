#
# Render and edit a person's PGP keys
#

class PersonPgpKeys < Vue
  def render
    committer = @@person.state.committer

    _div.row do
      _div.name 'PGP keys'

      _div.value do
        _ul committer.pgp do |key|
          _li do
            if key =~ /^[0-9a-fA-F ]+$/
              _samp do
                _a key, href: 'https://sks-keyservers.net/pks/lookup?' +
                  'op=index&search=0x' + key.gsub(' ', '')
              end
            else
              _samp key
            end
          end
        end
      end
    end
  end
end
