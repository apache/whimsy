if env.password
  ASF::LDAP.bind(env.user, env.password) do
    person = ASF::Person.find(@id)
    pmc = ASF::Committee.find(@pmc) if @targets.include? 'pmc'
    group = ASF::Group.find(@pmc) if @targets.include? 'commit'

    if @action == 'add'
      pmc.add(person) if pmc
      group.add(person) if group
    elsif @action == 'remove'
      pmc.remove(person) if pmc
      group.remove(person) if group
    end
  end
end

Committee.serialize(@pmc)
