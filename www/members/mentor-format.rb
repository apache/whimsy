# Utility methods and structs related to mentor data
require 'json'
require 'tzinfo'

class MentorFormat
  ROSTER = 'https://whimsy.apache.org/roster/committer/'
  MENTORS_SVN = 'https://svn.apache.org/repos/private/foundation/mentors/'
  MENTORS_LIST = 'https://whimsy.apache.org/member/mentors.cgi'
  PUBLICNAME = 'publicname'
  NOTAVAILABLE = 'notavailable'
  ERRORS = 'errors'
  TIMEZONE = 'timezone'
  TZ = TZInfo::Timezone.all_country_zone_identifiers

  # Read mapping of labels to fields
  def self.get_uimap(path)
    return JSON.parse(File.read(File.join(path, 'ui-map.json')))
  end
end