#
# convert attachment to pdf
#

message = Mailbox.find(@message)

begin
  source = message.find(@selected).as_pdf
  source.rewind

  output = SafeTempFile.new('output')

  name = @selected.sub(/\.\w+$/, '') + '.pdf'

  message.update_attachment @selected, content: source.read, name: name,
    mime: 'application/pdf'

ensure
  source.unlink if source
end

{attachments: message.attachments, selected: name}
