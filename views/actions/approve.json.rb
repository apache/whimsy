#
# Pre-app approval of an agenda item by a Director
#

pending = Pending.get(env.user, @agenda)

approved = pending['approved']
rejected = pending['rejected']

if @request == 'approve'
  approved << @attach unless approved.include? @attach
  rejected.delete @attach
else
  approved.delete @attach

  if @request == 'reject'
    rejected << @attach unless rejected.include? @attach
  end
end

Pending.put(env.user, pending)

pending
