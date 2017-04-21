#
# delete an attachment
#

message = Mailbox.find(@message)

message.delete_attachment @selected

{attachments: message.attachments, selected: name}
