#
# Render a person's other E-mail address(es)
#

class PersonEmailOther < Vue
  def render
    committer = @@person.state.committer

    _div.row do
      _div.name 'Email addresses (other)'

      _div.value do
        _ul committer.email_other do |mail|
          _li do
              _a mail, href: 'mailto:' + mail
          end
        end
      end
    end
  end
end
