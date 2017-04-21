Mailbox.fetch @mbox

mbox = Mailbox.new(@mbox)

mbox.parse

{messages: mbox.client_headers}
