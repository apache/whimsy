#{
# Creates JSON output from committee-info.txt with the following format:
#  "last_updated": "2016-03-04 04:50:00 UTC",
#  "committee_count": 210,
#  "roster_counts": {
#    "accumulo": 40,
#    ...
#  },
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

# If a second parameter is provided, also creates committee-retired info of the form:
#{
#  "last_updated": "2016-03-04 04:50:00 UTC",
#  "retired_count": 123,
#  "retired": {
#    "abdera": {
#      "display_name": "Abdera",
#      "description": "Atom Publishing Protocol Implementation",
#      "retired": "yyyy-mm".
#      "mlists": ["dev", "user", ...] // lists not yet shut down
#    },

require_relative 'public_json_common'
require 'whimsy/asf/board'

# gather committee info
committees = ASF::Committee.load_committee_info

# reformat the data
info = {
  last_updated: ASF::Committee.svn_change,
  committee_count: committees.size,
  roster_counts: nil
}

roster_counts = {}
info[:committees] = committees.map {|committee|
  schedule = committee.schedule.to_s.split(/,\s*/)
  schedule.unshift committee.report if committee.report != committee.schedule
  cname = committee.name.gsub(/[^-\w]/, '')
  data = {
    display_name: committee.display_name,
    site: committee.site,
    description: committee.description,
    mail_list: committee.mail_list,
    established: committee.established,
    report: schedule,
    # Convert {:name=>"Public Name", :id=>"availid"} to
    # "chair": { "availid": { "name": "Public Name" } }
    chair: committee.chairs.map {|chair| [chair[:id], {:name => chair[:name]}]}.to_h,
    roster_count: committee.roster.size,
    roster: committee.roster.sort.to_h, # sort entries by uid
    pmc: committee.pmc?
  }
  roster_counts[cname] = committee.roster.size
  data[:paragraph] = committee.paragraph if committee.paragraph
  [cname, data]
}.to_h
info[:roster_counts] = roster_counts

info[:officers] =
  ASF::Committee.officers.map { |officer|
    [officer.name.gsub(/[^-\w]/, ''),
      {
        display_name: officer.display_name,
        paragraph: officer.paragraph, # will always be present
        roster: officer.chairs.map {|e| [e[:id], {:name => e[:name]}]}.to_h
      }
    ]
  }.to_h

info[:board] = {
  roster: ASF::Board.directors(true)
}

public_json_output(info)

# Check if there is an unexpected entry date
# we only do this if the file has changed to avoid excessive reports
if changed? and @old_file
  # Note: symbolize_names=false to avoid symbolising variable keys such as pmc and user names
  # However the current JSON (info) uses symbols for fixed keys - beware!
  previous = JSON.parse(@old_file, :symbolize_names => false)
  previous = previous['committees']
  last_updated = info[:last_updated] # This is a Time instance
  # the joining date should normally be the same as the date when the file was updated:
  updated_day1 = last_updated.strftime("%Y-%m-%d") # day of update
  # and the date must be after the last time the data was checked.
  # Unfortunately the last_updated field is only updated when the content changes -
  # there is currently no record of when the last check was done.
  # For now, just assume that this is done every 15 mins. This may cause spurious reports
  # if the checks are ever suspended for longer and meanwhile changes occur.
  # Note: for those in an earlier timezone the date could be a few hours earlier
  updated_day2 = (last_updated - 3600 * 4).strftime("%Y-%m-%d") # day of previous update

  # for validating UIDs
  uids = ASF::Person.list().map(&:id)

  info[:committees].each { |pmc, entry|
    next if pmc == 'infrastructure' # no dates
    Wunderbar.warn "#{pmc}: no description found" if entry[:pmc] && !entry[:description]
    previouspmc = previous[pmc] # get the original details (if any)
    if previouspmc # we have an existing entry
      entry[:roster].each { |name, value|
        newdate = value[:date]
        if newdate.nil?
          Wunderbar.warn "Un-dated member for #{pmc}: #{name} #{value[:name]} #{newdate}"
          next
        end
        if previouspmc['roster'][name].nil? # new name, check the date is OK
          if newdate <= updated_day1 and newdate >= updated_day2 # in range
            Wunderbar.info "New member for #{pmc}: #{name} #{value[:name]} #{newdate}"
          elsif newdate > updated_day1
            Wunderbar.warn "Future-dated member for #{pmc}: #{name} #{value[:name]} #{newdate}"
          else
            Wunderbar.warn "Past-dated member for #{pmc}: #{name} #{value[:name]} #{newdate}"
          end
        else
          olddate = previouspmc['roster'][name]['date']
          if olddate != newdate
            Wunderbar.warn "Changed date member for #{pmc}: #{name} #{value[:name]} #{olddate} => #{newdate}"
          end
        end
      }
    else
      Wunderbar.info "New PMC detected: #{pmc}"
      # Could check that the joining dates are all the same?
    end
    entry[:roster].each { |id, _|
      Wunderbar.warn "#{pmc}: unknown uid '#{id}'" unless uids.include?(id)
    }
  }

  previous.each { |pmc, _|
    unless info[:committees][pmc]
      Wunderbar.info "Deleted PMC detected: #{pmc}"
    end
  }

end

# do we awant attic info?
if ARGV.length >= 2
  ARGV.shift # we have already used this
  require 'whimsy/asf/mlist'

  metadata = ASF::Committee.load_committee_metadata[:tlps]

  public_lists = Hash.new {|h, k| h[k] = Array.new}
  begin
    ASF::MLIST.list_types(true) do |dom, list, _|
      public_lists[dom.sub(/\.apache\.org$/, '')] << list
    end
  rescue StandardError => e
    Wunderbar.error e.inspect
  end

  # reformat the data
  attic = {last_updated: ASF::Committee.meta_change}

  data = {}

  active = info[:committees].keys

  metadata.each do |key, value|
    retired = value[:retired]
    if retired
      Wunderbar.warn "#{key} has no display name" unless value[:name]
      data[key] = {
        display_name: value[:name],
        retired: retired
      }
      data[key][:description] = value[:description] if value[:description]
      mlists = public_lists[key]
      if mlists.size > 0
        data[key][:mlists] = mlists
      end
    else
      unless active.include? key
        Wunderbar.warn "Has '#{key}'' retired? Could not find it in committee-info.txt!"
      end
    end
  end

  attic[:retired_count] = data.size
  attic[:retired] = data

  public_json_output(attic) # uses first ARGV entry
end
