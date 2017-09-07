#
# Render and edit a person's URLs
#

class PersonUrls < Vue
  def render
    committer = @@person.state.committer

    _div.row do
      _div.name 'Personal URL'

      _div.value do
        _ul committer.urls do |url|
          _li {_a url, href: url}
        end
      end
    end
  end
end
