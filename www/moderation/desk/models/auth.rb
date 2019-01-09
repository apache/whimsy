#
# What karma? 
# Used by mailbox
#
class Auth
  def self.info(env)
    ASF::Auth.decode(env)
    info = {id: env.user}

    person = ASF::Person.find(env.user)

# not needed ?
#    if ASF::Service.find('asf-secretary').members.include? person
#      info[:secretary] = true
#    end
#
#    if ASF::Service.find('apldap').members.include? person
#      info[:root] = true
#    end

    if person.asf_member?
      info[:member] = true
    end

#    if ASF.pmc_chairs.include? person
#      info[:pmc_chair] = true
#    end

#    info[:services] = person.services

    info[:project_owners] = person.project_owners.map(&:name)
    info
  end
end
