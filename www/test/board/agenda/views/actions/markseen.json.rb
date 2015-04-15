#
# Mark a set of comments as seen
#

pending = Pending.get(env.user, @agenda)

pending['seen'] = @seen

Pending.put(env.user, pending)

pending
