#
# Simplify access to JSON files in the /public/ directory
#

require 'json'
#require 'wunderbar'
require 'net/https'
require 'fileutils'

module Public
  DATAURI = 'https://whimsy.apache.org/public/'

  def self.getfile(pubname)
    local_copy = File.expand_path('../../../www/public/'+pubname, __FILE__.untaint).untaint
    if File.exist? local_copy
#      Wunderbar.info "Using local copy of #{pubname}"
      File.read(local_copy)
    else
#      Wunderbar.info "Fetching remote copy of #{pubname}"
      response = Net::HTTP.get_response(URI(DATAURI+pubname))
      raise ArgumentError, "'#{pubname}' #{response.message}" unless response.is_a?(Net::HTTPSuccess)
      response.body
    end
  end

  def self.getJSON(pubname)
    JSON.parse(getfile(pubname))
  end
end

# for test purposes
if __FILE__ == $0
  puts Public.getJSON('public_podling_status.json')['last_updated']
  puts Public.getJSON('public_ldap_services.json')['lastTimestamp']
end
