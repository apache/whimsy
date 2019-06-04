#
# Debugging tool model for holding any test data
#
class Debugger
  def self.serialize(committer, env)
    response = {env: env}
    pmc = ASF::Committee.find('whimsy')
    response[:pmc] = true if pmc.roster.has_key? committer.id
    return response
  end
end
