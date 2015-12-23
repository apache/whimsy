#
# burst a document into separate pages
#

month, hash = @message.match(%r{/(\d+)/(\w+)}).captures

mbox = Mailbox.new(month)
message = mbox.find(hash)

attachments = []

begin
  source = message.find(@selected).as_pdf

  Dir.mktmpdir do |dir|
    Kernel.system 'pdftk', source.path, 'burst', 'output',
      "#{dir}/page_%06d.pdf"

    pages = Dir["#{dir}/*.pdf"].sort.map {|name| name.untaint}

    format = @selected.sub(/\.\w+$/, '') + 
      "-%0#{pages.length.to_s.length}d.pdf"

    pages.each_with_index do |page, index|
      attachments << {
        name: format % (index+1),
        content: File.read(page),
        mime: 'application/pdf'
      }
    end
  end

  message.replace_attachment @selected, attachments

ensure
  source.unlink if source
end

{
  attachments: message.attachments, 
  selected: (attachments.empty? ? nil : attachments.first[:name])
}
