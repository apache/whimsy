#
# Simplify access to JSON files in the /public/ directory
#

require 'json'
require 'net/https'
require 'fileutils'

module Public
  # location of where public files are placed on the web
  DATAURI = 'https://whimsy.apache.org/public/'

  # contents of a given public file, read from local copy if possible,
  # fetched from the web otherwise
  def self.getfile(pubname)
    local_copy = File.expand_path('../../../www/public/' + pubname, __FILE__)
    if File.exist? local_copy
      File.read(local_copy)
    else
      response = Net::HTTP.get_response(URI(DATAURI + pubname))
      raise ArgumentError, "'#{pubname}' #{response.message}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end
  end

  # contents of a given public file, read from local copy if possible,
  # fetched from the web otherwise; parsed as JSON
  def self.getJSON(pubname)
    JSON.parse(getfile(pubname))
  end
end

# for test purposes
if __FILE__ == $0
  puts Public.getJSON('public_podling_status.json')['last_updated']
  puts Public.getJSON('public_ldap_services.json')['lastTimestamp']
end
