#
# convert attachment to pdf
#

message = Mailbox.find(@message)

begin
  source = message.find(@selected).as_pdf
  source.rewind

  name = @selected.sub(/\.\w+$/, '') + '.pdf'

  # If output file is empty, then the command failed
  raise "Failed to pdf-ize #{@selected} in #{@message}" unless File.size? source.path

  message.update_attachment @selected, content: source.read, name: name,
    mime: 'application/pdf'

ensure
  source.unlink if source
end

{attachments: message.attachments, selected: name}
