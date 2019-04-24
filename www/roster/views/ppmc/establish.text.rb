podling = ASF::Podling.find(@name)
@description ||= podling.description
chair = ASF::Person.find(@chair)

list = podling.owners.map {|person| [person.public_name, person.id]}
width = list.map {|name, id| name.length}.max

resolution = <<-EOF
Establish the Apache #{podling.display_name} Project

WHEREAS, the Board of Directors deems it to be in the best interests of the
Foundation and consistent with the Foundation's purpose to establish a Project
Management Committee charged with the creation and maintenance of open-source
software, for distribution at no charge to the public, related to
#{@description}.

NOW, THEREFORE, BE IT RESOLVED, that a Project Management Committee (PMC), to
be known as the "Apache #{podling.display_name} Project", be and hereby is
established pursuant to Bylaws of the Foundation; and be it further

RESOLVED, that the Apache #{podling.display_name} Project be and hereby is
responsible for the creation and maintenance of software related to
#{@description}; and be it further

RESOLVED, that the office of "Vice President, Apache #{podling.display_name}"
be and hereby is created, the person holding such office to serve at the
direction of the Board of Directors as the chair of the Apache
#{podling.display_name} Project, and to have primary responsibility for
management of the projects within the scope of responsibility of the Apache
#{podling.display_name} Project; and be it further

RESOLVED, that the persons listed immediately below be and hereby are appointed
to serve as the initial members of the Apache #{podling.display_name} Project:

*** LIST ***

NOW, THEREFORE, BE IT FURTHER RESOLVED, that #{chair.public_name} be appointed
to the office of Vice President, Apache #{podling.display_name}, to serve in
accordance with and subject to the direction of the Board of Directors and the
Bylaws of the Foundation until death, resignation, retirement, removal or
disqualification, or until a successor is appointed; and be it further

RESOLVED, that the Apache #{podling.display_name} Project be and hereby is
tasked with the migration and rationalization of the Apache Incubator
#{podling.display_name} podling; and be it further

RESOLVED, that all responsibilities pertaining to the Apache Incubator
#{podling.display_name} podling encumbered upon the Apache Incubator PMC are
hereafter discharged.
EOF

# reflow paragraphs
line_width = 72
resolution = resolution.split("\n\n").map do |paragraph|
  paragraph.gsub(/\s+/, ' ').
    gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip
end
resolution = resolution.join("\n\n")

# insert list of proposed PMC members
resolution.sub! '*** LIST ***',
  list.sort_by {|name, id| name}.
    map {|name, id| " * #{name.ljust(width)} <#{id}@apache.org>"}.join("\n")

resolution
