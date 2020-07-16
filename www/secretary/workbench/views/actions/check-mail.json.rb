# This code is invoked from workbench/views/index.js.rb

Mailbox.fetch @mbox

mbox = Mailbox.new(@mbox)

mbox.parse

{messages: mbox.client_headers}
