#
# Mark a set of comments as seen
#

Pending.update(env.user, @agenda) do |pending|
  pending['seen'] = @seen.to_h
end
