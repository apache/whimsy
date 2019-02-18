#
# Render and edit a person's E-mail addresses
#

class PersonEmail < Vue
  def render
    committer = @@person.state.committer

    _div.row do
      _div.name do
        _ 'Email addresses '
        _b do
          _ '(forwards)'          
        end
        
      end

      _div.value do
        _ul committer.mail do |url|
          _li do
            if committer.mail_default.include?(url)
              _b do
                _a url, href: 'mailto:' + url
              end
            else
              _a url, href: 'mailto:' + url
            end
          end
        end
      end
    end
  end
end
