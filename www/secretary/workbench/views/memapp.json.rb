require 'whimsy/asf/meeting-util'

# parse and return the contents of the latest memapp-received file

hoursremain = ASF::MeetingUtil.application_time_remaining[:hoursremain]

if hoursremain > 0 # Not yet expired
  table = ASF::MeetingUtil.parse_memapp_to_h.sort_by{|k| k[:name]}
else
  table = []
end

{received: table}
