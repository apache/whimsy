#
# drop part of drag and drop
#

message = Mailbox.find(@message)

begin
  selected = message.find(@selected).as_pdf

  tool = 'pdf270' if @direction.include? 'right'
  tool = 'pdf90' if @direction.include? 'left'
  tool = 'pdf180' if @direction.include? 'flip'

  Dir.chdir File.dirname(selected.path) do
    Kernel.system tool, '--quiet', '--suffix', 'rotated', selected.path
  end

  output = selected.path.sub(/\.pdf$/, '-rotated.pdf')
  puts output

  # If output file is empty, then the command failed
  raise "Failed to rotate #{@selected}" unless File.size? output

  name = @selected.sub(/\.\w+$/, '') + '.pdf'

  message.update_attachment @selected, content: IO.binread(output), name: name,
    mime: 'application/pdf'

rescue
  Wunderbar.error "Cannot process #{@selected}"
  raise
ensure
  selected.unlink if selected
  File.unlink output if output
end

{attachments: message.attachments, selected: name}
