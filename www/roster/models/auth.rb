class Auth
  def self.info(env)
    ASF::Auth.decode(env)
    info = {id: env.user}

    secretary = ASF::Service.find('asf-secretary')
    if secretary.members.include?  ASF::Person.find(env.user)
      info[:secretary] = true
    end

    info
  end
end
