#
# Join multiple PDF pages
#

begin
  outputname = 'pages.pdf'
  message = Mailbox.find(@message)
  attachments = message.attachments

  Dir.mktmpdir do |dir|
    pages = []
    attachments.each do |attach|
      pages << message.find(attach).as_pdf.path # this is where the attachment is extracted
    end

    # Join the extracted pages
    outputpath = File.join(dir, outputname)
    Kernel.system 'pdfunite', *pages, outputpath

    attachment = {
      name: 'pages.pdf',
      content: File.binread(outputpath), # must use binary read
      mime: 'application/pdf'
    }

    message.replace_all_attachments attachment
  end

rescue
  Wunderbar.error "Cannot process #{@selected}"
  raise
end

{
  attachments: message.attachments,
  selected: outputname
}
