# Utility methods and structs related to mentor data
require 'json'
require 'tzinfo'

class MentorFormat
  ROSTER = 'https://whimsy.apache.org/roster/committer/'
  MENTORS_SVN = ASF::SVN.svnurl!('foundation_mentors')
  MENTORS_LIST = 'https://whimsy.apache.org/member/mentors.cgi'
  PUBLICNAME = 'publicname'
  NOTAVAILABLE = 'notavailable'
  ERRORS = 'errors'
  TIMEZONE = 'timezone'
  TZ = TZInfo::Timezone.all_country_zone_identifiers
  PREFERS_TYPES = [
    'email',
    'phone',
    'Slack',
    'irc',
    'Hangouts',
    'Facebook',
    'Skype',
    'other (text chat)',
    'other (video chat)'
  ]
  LANGUAGES = [ # Wikipedia top list by total speakers, plus EU
    'Arabic',
    'Bengali',
    'Bulgarian',
    'Chinese',
    'Croatian',
    'Czech',
    'Danish',
    'Dutch',
    'English',
    'Estonian',
    'Finnish',
    'French',
    'German',
    'Greek',
    'Hindi',
    'Hungarian',
    'Indonesean',
    'Irish',
    'Italian',
    'Japanese',
    'Korean',
    'Latvian',
    'Lithuanian',
    'Maltese',
    'Marathi',
    'Polish',
    'Portugese',
    'Punjabi',
    'Romanian',
    'Russian',
    'Slovak',
    'Slovene',
    'Spanish',
    'Swahili',
    'Swedish',
    'Tamil',
    'Telugu',
    'Thai',
    'Turkish',
    'Vietnamese'
  ]

  # Read mapping of labels to fields
  def self.get_uimap(path)
    return JSON.parse(File.read(File.join(path, 'ui-map.json')))
  end
end