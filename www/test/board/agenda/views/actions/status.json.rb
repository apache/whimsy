#
# Add action item update to an agenda item
#

pending = Pending.get(env.user, @agenda)
pending['status'] ||= {}

action = @action
action += " #{@pmc}" if @pmc

pending['status'][action] = @status

Pending.put(env.user, pending)

pending
