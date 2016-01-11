#
# drop part of drag and drop
#

message = Mailbox.find(@message)

begin
  source = message.find(@source).as_pdf
  target = message.find(@target).as_pdf

  output = Tempfile.new('output')

  Kernel.system 'pdftk', target.path, source.path, 'cat', 'output',
    output.path

  name = @target.sub(/\.\w+$/, '') + '.pdf'

  message.update_attachment @target, content: output.read, name: name,
    mime: 'application/pdf'

  message.delete_attachment @source

ensure
  File.unlink source.path.untaint if source
  File.unlink target.path.untaint if target
  File.unlink output.path.untaint if output
end

{attachments: message.attachments, selected: name}
