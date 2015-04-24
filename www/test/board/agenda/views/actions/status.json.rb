#
# Add action item status updates to pending list
#

pending = Pending.get(env.user, @agenda)
pending['status'] ||= {}

action = @action
action += @pmc if @pmc

pending['status'][action] = 
  @status.strip.gsub(/\s+/, ' ').gsub(/(.{1,62})(\s+|\Z)/, "\\1\n").chomp

Pending.put(env.user, pending)

pending
