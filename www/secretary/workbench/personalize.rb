#
# Per user email personalizations
#

class Wunderbar::JsonBuilder
  def _personalize_email(user)
    if user == 'clr'

      @from = 'Craig L Russell <secretary@apache.org>'
      @sig = %{
        -- Craig L Russell
        Secretary, Apache Software Foundation
      }

    elsif user == 'rubys'

      @from = 'Sam Ruby <rubys@apache.org>'
      @sig = %{
        -- Sam Ruby
        Assistant Secretary, Apache Software Foundation
      }

    else

      person = ASF::Person.find(user)

      @from = "#{person.public_name} <#{user}@apache.org>"
      @sig = %{
        -- #{person.public_name}
        Apache Software Foundation Secretarial Team
      }

    end

    # strip extraneous whitespace from signature
    @sig = @sig.gsub(/^\s*/, '').strip
  end
end
