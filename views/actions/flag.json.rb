#
# Flag/unflag an item for discussion
#

Pending.update(env.user, @agenda) do |pending|

  flagged = pending['flagged']
  unflagged = pending['unflagged']

  if @request == 'flag'
    flagged << @attach unless flagged.include? @attach
    unflagged.delete @attach
  else
    unflagged << @attach unless unflagged.include? @attach
    approved.delete @attach
  end
end
