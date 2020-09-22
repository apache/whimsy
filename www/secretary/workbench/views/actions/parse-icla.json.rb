# parse an icla from a PDF

require_relative '../../../iclaparser'
require_relative '../../models/mailbox'

attachment = URI.decode(@attachment) # derived from a URI

# WHIMSY-322
ALIASES = {
  "solr" => "lucene",
}

if attachment.end_with? '.pdf'
  message = Mailbox.find(@message)

  path = message.find(attachment).as_file.path

  parsed = ICLAParser.parse(path)

  # Extract the project and adjust if necessary
  project = parsed[:Project]
  parsed [:PDFProject] = project # retain the original value

  if project
    project.downcase!
    projects = (ASF::Podling.current+ASF::Committee.pmcs).map(&:name)
    unless projects.include? project
      if project.start_with? 'commons-'
        parsed[:Project] = 'commons'
      elsif project.start_with? 'log'
        parsed[:Project] = 'logging'
      else
        tmp = ALIASES[project]
        parsed[:Project] = tmp if tmp
      end
    end
  end
else
  parsed = {}
end

{parsed: parsed}