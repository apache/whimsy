#
# Pre-app approval of an agenda item by a Director
#

pending = Pending.get(env.user, @agenda)

approved = pending['approved']
rejected = pending['rejected']

if @request == 'approve'
  approved << @attach unless approved.include? @attach
  rejected.delete @attach
elsif @request == 'reject'
  rejected << @attach unless rejected.include? @attach
else
  approved.delete @attach
end

Pending.put(env.user, pending)

pending
