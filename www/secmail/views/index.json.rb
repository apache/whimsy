# find indicated mailbox in the list of available mailboxes
available = Dir["#{ARCHIVE}/*.yml"].sort
index = available.find_index "#{ARCHIVE}/#{@mbox}.yml"

# if found, process it
if index
  # return previous mailbox name and headers for the messages in the mbox
  {
    mbox: (File.basename(available[index-1].untaint, '.yml') if index > 0),
    messages: Mailbox.new(@mbox).client_headers
  }
end
