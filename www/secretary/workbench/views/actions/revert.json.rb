#
# revert to the original document
#

message = Mailbox.revert(@message)

# TODO: ensure correct attachment is selected
{attachments: message.attachments, selected: message.attachments.first}
