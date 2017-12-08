#
# Add/replace a note
#

# extract message
message = Mailbox.find(@message)

# update notes
message.headers[:secmail] ||= {}
message.headers[:secmail][:notes] = @notes

# update message
message.write_headers
