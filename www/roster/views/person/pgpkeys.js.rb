#
# Render and edit a person's PGP keys
#

class PersonPgpKeys < Vue
  def render
    committer = @@person.state.committer

    _div.row data_edit: 'pgpkeys' do
      _div.name 'PGP keys'

      _div.value do
        if @@edit == :pgpkeys

          _form method: 'post' do
            current = 1
            prefix = 'pgpkeys' # must agree with pgpkeys.json.rb
            _input type: 'hidden', name: 'array_prefix', value: prefix

            _div committer.pgp do |key|
              _input style: 'font-family:Monospace', size: 52, name: prefix + current, value: key
              _br
              current += 1
            end
            # Spare field to allow new entry to be added
            _input style: 'font-family:Monospace', size: 52, name: prefix + current, placeholder: '<enter a new 40 hex char key>'
            _br

            _input type: 'submit', value: 'submit'
          end

        else
          if committer.pgp.empty?
            _ul do
              _li '(none defined)'
            end
          else
            _ul committer.pgp do |key|
              nbsp = "\u00A0" # non-breaking space as UTF-8
              keynb = key.gsub(' ', nbsp) # ensure multiple spaces appear as such
              _li do
                if key =~ /^[0-9a-fA-F ]+$/
                  keysq = key.gsub(' ', '') # strip spaces for length check and lookup
                  _samp style: 'font-family:Monospace' do
                    _a keynb, href: 'https://keyserver.ubuntu.com/pks/lookup?' +
                      'op=index&fingerprint=on&search=0x' + keysq
                    unless keysq.length == 40
                      _span.bg_danger ' ?? Expecting exactly 40 hex characters (plus optional spaces)'
                    end
                  end
                else
                  _samp style: 'font-family:Monospace' do
                    _ keynb
                    _span.bg_danger ' ?? Expecting exactly 40 hex characters (plus optional spaces)'
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
