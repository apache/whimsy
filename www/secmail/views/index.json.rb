if @mbox =~ /^\d+$/
  # find indicated mailbox in the list of available mailboxes
  available = Dir["#{ARCHIVE}/*.yml"].sort
  index = available.find_index "#{ARCHIVE}/#{@mbox}.yml"

  # if found, process it
  if index
    # fetch a list of headers for all messages in the maibox with attachments
    headers = Mailbox.new(@mbox).headers.to_a.select do |id, message|
      message[:attachments] and not message[:status] == :deleted
    end

    # extract relevant fields from the headers
    headers.map! do |id, message|
      {
        time: message[:time],
        href: "#{message[:source]}/#{id}/",
        from: message[:from],
        subject: message['Subject']
      }
    end

    # select previous mailbox
    mbox = available[index-1].untaint

    # return mailbox name and messages
    {
      mbox: (File.basename(mbox, '.yml') if index > 0),
      messages: headers.sort_by {|message| message[:time]}.reverse
    }
  end
end
