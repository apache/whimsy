#
# Render and edit a person's URLs
#

class PersonUrls < React
  def render
    committer = @@person.state.committer

    _tr do
      _td 'Personal URL'

      _td do
        _ul committer.urls do |url|
          _li {_a url, href: url}
        end
      end
    end
  end
end
