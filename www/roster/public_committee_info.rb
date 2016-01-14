require 'bundler/setup'

require 'json'
require 'whimsy/asf'

GEMVERSION = Gem.loaded_specs['whimsy-asf'].version.to_s rescue nil
  # rescue is to allow for running with local library rather than a Gem

# parse arguments for output file name
if ARGV.length == 0 or ARGV.first == '-'
  output = STDOUT
else
  # exit quickly if there has been no change
  if File.exist? ARGV.first
    source = "#{ASF::SVN['private/committers/board']}/committee-info.txt"
    lib = File.expand_path('../../../lib', __FILE__)
    mtime = Dir["#{lib}/**/*"].map {|file| File.mtime(file)}.max
    mtime = [mtime, File.mtime(source), File.mtime(__FILE__)].max
    if File.mtime(ARGV.first) >= mtime
      previous_results = JSON.parse(File.read ARGV.first) rescue {}
      exit 0 if previous_results['gem_version'] == GEMVERSION
    end
  end

  output = File.open(ARGV.first, 'w')
end

# gather committee info
committees = ASF::Committee.load_committee_info
info = {last_updated: ASF::Committee.svn_change, gem_version: GEMVERSION}
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

# output results
output.puts JSON.pretty_generate(info)
output.close
