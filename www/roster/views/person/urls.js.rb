#
# Render and edit a person's URLs
#

class PersonUrls < Vue
  def render
    committer = @@person.state.committer

    _div.row data_edit: 'urls' do
      _div.name 'Personal URL'

      _div.value do
        if @@edit == :urls

          _form method: 'post' do
            current = 1
            prefix = 'urls' # must agree with urls.json.rb
            _input type: 'hidden', name: 'array_prefix', value: prefix

            _div committer.urls do |url|
              _input name: prefix + current, value: url
              _br
              current += 1
            end
            # Spare field to allow new entry to be added
            _input name: prefix + current, placeholder: '<enter a new URL>'
            _br

            _input type: 'submit', value: 'submit'
          end

        else
          if committer.urls.empty?
            _ul do
              _li '(none defined)'
            end
          else
            _ul committer.urls do |url|
              if url =~ %r{^https?://}
                _li {_a url, href: url}
              else
                _li.bg_warning do
                  _ url
                  _ ' - (invalid: must start with https?://)'
                end
              end
            end
          end
      end
      end
    end
  end
end
