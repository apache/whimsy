#
# send reminders for action items
#

ASF::Mail.configure

sent = {}
unsent = []

# extract a list of people from the agenda and committee-info.txt
agenda = Agenda.parse(@agenda, :full)
people = agenda[1]['people'].to_a +
  (ASF::Committee.officers+ASF::Committee.nonpmcs).map(&:chairs).flatten.uniq.
  map {|person| [person[:id], person.merge(role: :info)]}

# build a mapping of first names to availids
order = {director: 4, officer: 3, guest: 2, info: 1}
name_map =  people.sort_by {|key,value| order[value[:role]]}.
    map {|key, value| [value[:name].split(' ').first, key]}.to_h

# add full name mappings
name_map.merge! people.
  map {|key, value| [value[:name].gsub(/[^\w]/, ''), key]}.to_h

# extract values for common fields
from = @from
unless from
  sender = ASF::Person.find(env.user)
  from = "#{sender.public_name.inspect} <#{sender.id}@apache.org>"
end

template = File.read("#{FOUNDATION_BOARD}/templates/remind-action.erb")

# iterate over the action items
@actions.group_by {|action| action['owner']}.each do |owner, actions|
  person = ASF::Person[name_map[owner]]

  # bail if owner can't be found
  unless person
    unsent << owner
    next
  end

  # construct email
  mail = Mail.new do
    from from
    to "#{person.public_name} <#{person.id}@apache.org>"
    bcc "board-private@apache.org"
    subject 'Action Item reminder'

    body Erubis::Eruby.new(template).result(binding)
  end

  # deliver mail
  mail.deliver! unless @dryrun
  sent[person.id] = mail.to_s
end

# provide a response to the request
{count: sent.length, unsent: unsent, sent: sent, dryrun: @dryrun}
