#
# pdf rotations
#

message = Mailbox.find(@message)

begin
  selected = message.find(@selected).as_pdf

  options = %w(--angle 270 --rotateoversize true) if @direction.include? 'right'
  options = %w(--angle 90 --rotateoversize true) if @direction.include? 'left'
  options = %w(--angle 180) if @direction.include? 'flip'

  raise "Invalid direction #{@direction}" unless options

  Kernel.system 'pdfjam', *options, '--quiet', '--suffix', 'rotated', '--fitpaper', 'true', selected.path, {chdir: File.dirname(selected.path)}

  output = selected.path.sub(/\.pdf$/, '-rotated.pdf')

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
  File.unlink output if output and File.exist? output
end

{attachments: message.attachments, selected: name}
