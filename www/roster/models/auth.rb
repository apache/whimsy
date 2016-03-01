class Auth
  def self.info(env)
    ASF::Auth.decode(env)
    info = {id: env.user}

    user = ASF::Person.find(env.user)

    if ASF::Service.find('asf-secretary').members.include? user
      info[:secretary] = true
    end

    if ASF::Service.find('apldap').members.include? user
      info[:root] = true
    end

    if user.asf_member?
      info[:member] = true
    end

    info
  end
end
