require 'mail'

Mail.defaults do
  delivery_method :sendmail

  if $USER == 'clr'

    @from = 'Craig L Russell <clr@apache.org>'
    @sig = %{
      -- Craig L Russell
      Secretary, Apache Software Foundation
    }

  elsif $USER == 'rubys'

    @from = 'Sam Ruby <rubys@apache.org>'
    @sig = %{
      -- Sam Ruby
      Assistant Secretary, Apache Software Foundation
    }

  elsif $USER == 'jcarman'

    @from = 'James Carman <jcarman@apache.org>'
    @sig = %{
      -- James Carman
      Apache Software Foundation Secretarial Team
    }

  elsif $USER == 'sanders'

    @from = 'Scott Sander <sanders@apache.org>'
    @sig = %{
      -- Scott Sander
      Apache Software Foundation Secretarial Team
    }

  elsif $USER == 'mnour'

    @from = 'Mohammad Nour El-Din <mnour@apache.org>'
    @sig = %{
      -- Mohammad Nour El-Din
      Apache Software Foundation Secretarial Team
    }
  end
end


