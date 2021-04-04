#
# burst a document into separate pages
#

message = Mailbox.find(@message)

attachments = []

begin
  source = message.find(@selected).as_pdf

  Dir.mktmpdir do |dir|
    Kernel.system 'pdfseparate', source.path, "#{dir}/page_%d.pdf"

    # The directory name may include digits, so narrow down the matching
    pages = Dir["#{dir}/page_*.pdf"].sort_by {|name| name[/page_(\d+)/,1].to_i}

    format = @selected.sub(/\.\w+$/, '') +
      "-%0#{pages.length.to_s.length}d.pdf"

    pages.each_with_index do |page, index|
      attachments << {
        name: format % (index+1),
        content: File.binread(page), # must use binary read
        mime: 'application/pdf'
      } if File.size? page # skip empty output files
    end
  end

  # Don't replace if no output was produced
  message.replace_attachment @selected, attachments unless attachments.empty?
rescue
  Wunderbar.error "Cannot process #{@selected}"
  raise
ensure
  source.unlink if source
end

{
  attachments: message.attachments,
  selected: (attachments.empty? ? nil : attachments.first[:name])
}
