require 'whimsy/asf/meeting-util'

# parse and return the contents of the latest memapp-received file

# Application expiry is now handled by the GUI
table = ASF::MeetingUtil.parse_memapp_to_h.sort_by{|k| k[:name]}

{received: table}
