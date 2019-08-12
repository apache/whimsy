# ASF members and PMC chairs can post anything, everybody else can only post
# to updates for the PMCs that they belong to.
user = env.respond_to?(:user) && ASF::Person.find(env.user)
unless !user or user.asf_member? or ASF.pmc_chairs.include? user
  projects = user.committees.map(&:name)
  @report_status.each do |project, status|
    unless projects.include? project
      status 403 # Forbidden
      return "Not authorized to post #{project}"
    end
  end
end

# apply the updates
Reporter.drafts env, @report_status
