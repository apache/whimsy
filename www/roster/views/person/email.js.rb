#
# Render and edit a person's E-mail addresses
#

class PersonEmail < React
  def render
    committer = @@person.state.committer

    _tr do
      _td 'Email addresses'

      _td do
        _ul committer.mail do |url|
          _li do
            _a url, href: 'mailto:' + url
          end
        end
      end
    end
  end
end
