#
# Add comments to an agenda item
#

pending = Pending.get(env.user, @agenda)
pending['initials'] = @initials
pending['agenda'] = @agenda

comments = pending['comments']

if not @comment or @comment.strip.empty?
  comments.delete @attach
else
  comments[@attach] = @comment
end

Pending.put(env.user, pending)

pending
