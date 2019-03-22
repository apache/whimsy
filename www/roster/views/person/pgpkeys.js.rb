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
              k = key.gsub(' ', '')
              _samp do
                _a key, target: '_blank', href: 'https://sks-keyservers.net/pks/lookup?' +
                  'op=index&fingerprint=on&hash=on&search=0x' + k
                unless k.length == 40
                  _span.bg_danger ' ?? Expecting exactly 40 hex characters (plus optional spaces)'
                end
              end
            else
              _samp do
                _ key
                _span.bg_danger ' ?? Expecting exactly 40 hex characters (plus optional spaces)'
              end
            end
          end
        end
      end
    end
  end
end
