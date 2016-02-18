#
# Pre-app approval/unapproval/flagging/unflagging of an agenda item

Pending.update(env.user, @agenda) do |pending|
  agenda = Agenda.parse @agenda, :full
  @initials ||= pending['initials']

  approved = pending['approved']
  unapproved = pending['unapproved']
  flagged = pending['flagged']
  unflagged = pending['unflagged']

  case @request
  when 'approve'
    unapproved.delete @attach
    approved << @attach unless approved.include? @attach or
      agenda.find {|item| item[:attach] == @attach and
        item['approved'].include? @initials}

  when 'unapprove'
    approved.delete @attach
    unapproved << @attach unless unapproved.include? @attach or
      not agenda.find {|item| item[:attach] == @attach and
        item['approved'].include? @initials}

  when 'flag'
    unflagged.delete @attach
    flagged << @attach unless flagged.include? @attach or
      agenda.find {|item| item[:attach] == @attach and
        Array(item['flagged_by']).include? @initials}

  when 'unflag'
    flagged.delete @attach
    unflagged << @attach unless unflagged.include? @attach or
      not agenda.find {|item| item[:attach] == @attach and
        Array(item['flagged_by']).include? @initials}
  end
end
