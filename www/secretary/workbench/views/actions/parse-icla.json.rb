# parse an icla from a PDF

require_relative '../../../iclaparser'
require_relative '../../models/mailbox'

attachment = URI.decode(@attachment) # derived from a URI

if attachment.end_with? '.pdf'
  message = Mailbox.find(@message)
  
  path = message.find(attachment).as_file.path
  
  parsed = ICLAParser.parse(path)
else
  parsed = {}
end

{parsed: parsed}