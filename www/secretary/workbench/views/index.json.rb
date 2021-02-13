# find indicated mailbox in the list of available mailboxes
# This code is invoked by workbench/server.rb
available = Dir[File.join(ARCHIVE, "*.yml")].sort
index = available.find_index File.join(ARCHIVE, "#{@mbox}.yml")

# if found, process it
if index
  prevmbox = nil

  if index > 0
    prevmbox = available[index-1]
    prevmbox = nil unless YAML.load_file(prevmbox).any? do |key, mail|
      mail[:status] != :deleted and not Message.attachments(mail).empty?
    end
  end

  # return previous mailbox name and headers for the messages in the mbox
  {
    mbox: (File.basename(prevmbox, '.yml') if prevmbox),
    messages: Mailbox.new(@mbox).client_headers
  }
end
