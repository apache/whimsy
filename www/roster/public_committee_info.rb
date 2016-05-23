# Creates JSON output from committee-info.txt with the following format:
#{
#  "last_updated": "2016-03-04 04:50:00 UTC",
#  "committees": {
#    "abdera": {
#      "display_name": "Abdera",
#      "site": "http://abdera.apache.org/",
#      "description": "Atom Publishing Protocol Implementation",
#      "mail_list": "abdera",
#      "established": "11/2008",
#      "report": [
#        "Next month: missing in February",
#        "February",
#        "May",
#        "August",
#        "November"
#      ],
#      "chair": {
#        "availid": {
#          "name": "Some One"
#        }
#      },
#      "roster": {
#        "availid": {
#          "name": "Some One",
#          "date": "2009-10-21"
#         },
#      ...
#      },
#      "pmc": true
#    },

require_relative 'public_json_common'

# gather committee info
committees = ASF::Committee.load_committee_info

# reformat the data
info = {last_updated: ASF::Committee.svn_change}

info[:committees] = Hash[committees.map {|committee|
  schedule = committee.schedule.to_s.split(/,\s*/)
  schedule.unshift committee.report if committee.report != committee.schedule

  [committee.name.gsub(/[^-\w]/,''), {
    display_name: committee.display_name,
    site: committee.site,
    description: committee.description,
    mail_list: committee.mail_list,
    established: committee.established,
    report: schedule,
    # Convert {:name=>"Public Name", :id=>"availid"} to 
    # "chair": { "availid": { "name": "Public Name" } }
    chair: Hash[committee.chairs.map {|chair|
      [chair[:id], :name => chair[:name] ]}],
    roster: committee.roster,
    pmc: !ASF::Committee.nonpmcs.include?(committee)
  }]
}]

public_json_output(info)

# Check if there is an unexpected entry
# we only do this if the file has changed to avoid excessive reports
if changed? or true
  last_updated = info[:last_updated]
  info[:committees].each { |pmc, entry|
    entry[:roster].each { |name, value|
      jdate = value[:date]
      if jdate
        joined = Date.parse(jdate,'').to_time
        if joined > last_updated
          msg = "Unexpected joining date: PMC: #{pmc} Id: #{name} entry: #{value} (last_updated: #{last_updated})"
          Wunderbar.warn msg
          sendMail('Error detected processing committee-info.txt', msg)
        end
      end
    }
  }
end
