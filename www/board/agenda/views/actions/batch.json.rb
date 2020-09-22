#
# Batch apply offline updates

Pending.update(env.user, @agenda) do |pending|
  agenda = Agenda.parse @agenda, :full
  @initials ||= pending['initials']

  approved = pending['approved']
  unapproved = pending['unapproved']
  flagged = pending['flagged']
  unflagged = pending['unflagged']
  comments = pending['comments']

  if @pending['approve']
    @pending['approve'].each do |attach, request|
      if request == 'approve'
        unapproved.delete attach
        approved << attach unless approved.include? attach or
          agenda.find {|item| item[:attach] == attach and
            item['approved'].include? @initials}
      else
        approved.delete attach
        unapproved << attach unless unapproved.include? attach or
          not agenda.find {|item| item[:attach] == attach and
            item['approved'].include? @initials}
      end
    end
  end

  if @pending['flag']
    @pending['flag'].each do |attach, request|
      if request == 'flag'
        unflagged.delete attach
        flagged << attach unless flagged.include? attach or
          agenda.find {|item| item[:attach] == attach and
            Array(item['flagged_by']).include? @initials}
      else
        flagged.delete attach
        unflagged << attach unless unflagged.include? attach or
          not agenda.find {|item| item[:attach] == attach and
            Array(item['flagged_by']).include? @initials}
      end
    end
  end

  if @pending['comment']
    @pending['comment'].each do |attach, comment|
      if comment.empty?
        comments.delete attach
      else
        comments[attach] = comment
      end
    end
  end
end
