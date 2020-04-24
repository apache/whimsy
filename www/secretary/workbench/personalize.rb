#
# Per user email personalizations
#

class Wunderbar::JsonBuilder
  def _personalize_email(user)
    if user == 'clr'

      @from = 'Craig L Russell <clr@apache.org>'
      @sig = %{
        --
        Craig L Russell
        Assistant Secretary, Apache Software Foundation
      }

    elsif user == 'mattsicker'

      @from = 'Matt Sicker <secretary@apache.org>'
      @sig = %{
        --
        Matt Sicker
        Secretary, Apache Software Foundation
      }

    else

      person = ASF::Person.find(user)

      @from = "#{person.public_name} <#{user}@apache.org>".untaint
      @sig = %{
        --
        #{person.public_name}
        Apache Software Foundation Secretarial Team
      }

    end

    # strip extraneous whitespace from signature
    @sig = @sig.gsub(/^\s*/, '').strip
  end
end
