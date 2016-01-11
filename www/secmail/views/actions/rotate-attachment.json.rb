#
# drop part of drag and drop
#

message = Mailbox.find(@message)

begin
  selected = message.find(@selected).as_pdf

  direction = 'Right' if @direction.include? 'right'
  direction = 'Left' if @direction.include? 'left'
  direction = 'Down' if @direction.include? 'flip'

  output = SafeTempFile.new('output')

  Kernel.system 'pdftk', selected.path, 'cat', "1-end#{direction}", 'output',
    output.path

  name = @selected.sub(/\.\w+$/, '') + '.pdf'

  message.update_attachment @selected, content: output.read, name: name,
    mime: 'application/pdf'

ensure
  selected.unlink if selected
  output.unlink if output
end

{attachments: message.attachments, selected: name}
