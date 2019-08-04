#
# Add action item status updates to pending list
#

Pending.update(env.user, @agenda) do |pending|
  pending['status'] ||= []

  # identify the action to be updated
  update = {
    owner: @owner,
    text: @text,
    pmc: @pmc,
    date: @date
  }

  # search for a match against previously pending status updates
  match = nil
  pending['status'].each do |status|
    found = true
    update.each do |key, value|
      found=false if value != status[key]
    end
    match = status if found
  end

  # if none found, add update to the list
  pending['status'] << update if not match

  # change the status in the update
  (match || update)[:status] =
    @status.strip.gsub(/\s+/, ' ').
      gsub(/(.{1,62})(\s+|\Z)/, '\\1' + "\n".ljust(15)).strip

  # if change is reverted, remove item from the pending queue
  if match
    parsed = Agenda.parse(@agenda, :quick)
    actions = parsed.find {|item| item['title'] == 'Action Items'}
    pending['status'].delete match if actions['actions'].include? match
  end
end
