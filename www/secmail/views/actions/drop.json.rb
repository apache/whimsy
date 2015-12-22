#
# drop part of drag and drop
#

month, hash = @message.match(%r{/(\d+)/(\w+)}).captures

mbox = Mailbox.new(month)
message = mbox.find(hash)

begin
  source = message.find(@source).as_pdf
  target = message.find(@target).as_pdf

  output = Tempfile.new('output')

  Kernel.system 'pdftk', target.path, source.path, 'cat', 'output',
    output.path

  message.update_attachment @target, content: output.read,
    mime: 'application/pdf'

  message.delete_attachment @source

ensure
  source.unlink if source
  target.unlink if target
  output.unlink if output
end

{attachments: message.attachments, selected: @target}
