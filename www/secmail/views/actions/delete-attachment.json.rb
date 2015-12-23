#
# delete an attachment
#

month, hash = @message.match(%r{/(\d+)/(\w+)}).captures

mbox = Mailbox.new(month)
message = mbox.find(hash)

message.delete_attachment @selected

{attachments: message.attachments, selected: name}
