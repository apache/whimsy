# parse an icla from a PDF

require 'uri'
require_relative '../../../iclaparser'
require_relative '../../models/mailbox'


attachment = URI::RFC2396_Parser.new.unescape(@attachment) # derived from a URI

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
  if project
    parsed[:PDFProject] = project.dup # retain the original value
    project = project.downcase.sub('apache ', '')
    projects = (ASF::Podling.current + ASF::Committee.pmcs).map(&:name)
    if projects.include? project
      parsed[:Project] = project
    else
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
