#
# Render and edit a person's E-mail addresses
#

class PersonEmail < Vue
  def render
    committer = @@person.state.committer

    _div.row do
      _div.name 'Email addresses'

      _div.value do
        _ul committer.mail do |url|
          _li do
            _a url, href: 'mailto:' + url
          end
        end
      end
    end
  end
end
