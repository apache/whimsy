#
# Per user email personalizations
#

class Wunderbar::JsonBuilder
  def _personalize_email(user)
    secs = Hash.new
    ASF::Committee.officers.map{ |officer|
      if officer.name == 'secretary' or officer.name == 'assistantsecretary'
        secs[officer.chairs.first[:id]] = {
          name: officer.chairs.first[:name],
          office: officer.display_name,
        }
      end
    }
    sec = secs[user]
    if sec
      @from = "#{sec[:name]} <#{user}@apache.org>"
      @sig = %{
        --
        #{sec[:name]}
        #{sec[:office]}, Apache Software Foundation
      }
    else

      person = ASF::Person.find(user)

      @from = "#{person.public_name} <#{user}@apache.org>"
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
