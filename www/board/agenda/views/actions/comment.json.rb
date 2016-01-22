#
# Add comments to an agenda item
#

Pending.update(env.user, @agenda) do |pending|
  pending['initials'] = @initials
  pending['agenda'] = @agenda

  comments = pending['comments']

  if not @comment or @comment.strip.empty?
    comments.delete @attach
  else
    comments[@attach] = @comment
  end
end
