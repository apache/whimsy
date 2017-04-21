#
# update cc and bcc in a message
#

message = Mailbox.find(@message)

message.cc = @cc
message.bcc = @bcc

message.write_headers

headers = message.headers.dup
headers.delete :attachments
{headers: headers}
