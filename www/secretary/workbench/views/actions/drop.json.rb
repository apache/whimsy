#
# drop part of drag and drop
#

message = Mailbox.find(@message)

begin
  source = message.find(@source).as_pdf
  target = message.find(@target).as_pdf

  # binary encoding was used by the SafeTempFile class, now removed
  # It may no longer be necessary, but it probably does no harm
  output = Tempfile.new('output', encoding: Encoding::BINARY)

  Kernel.system 'pdfunite', target.path, source.path, output.path

  name = @target.sub(/\.\w+$/, '') + '.pdf'

  # If output file is empty, then the command failed
  raise "Failed to concatenate #{@target} and #{@source}" unless File.size? output

  message.update_attachment @target, content: output.read, name: name,
    mime: 'application/pdf'

  message.delete_attachment @source

rescue StandardError => e
  Wunderbar.error "Failed to concatenate #{@target} and #{@source}: #{e}"
  raise
ensure
  source&.unlink
  target&.unlink
  output&.unlink
end

{attachments: message.attachments, selected: name}
