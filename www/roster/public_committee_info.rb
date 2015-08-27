require 'json'
require 'whimsy/asf'

# parse arguments for output file name
if ARGV.length == 0 or ARGV.first == '-'
  output = STDOUT
else
  # exit quickly if there has been no change
  if File.exist? ARGV.first
    source = "#{ASF::SVN['private/committers/board']}/committee-info.txt"
    mtime = [File.mtime(source), File.mtime(__FILE__)].max
    exit 0 if File.mtime(ARGV.first) >= mtime
  end

  output = File.open(ARGV.first, 'w')
end

# gather committee info
committees = ASF::Committee.load_committee_info
info = {last_updated: ASF::Committee.svn_change}
info[:committees] = Hash[committees.map {|committee|
  [committee.name.gsub(/[^-\w]/,''), {
    display_name: committee.display_name,
    established: committee.established,
    report: committee.report,
    chair: Hash[committee.chairs.map {|chair|
      [chair.delete(:id), chair]}],
    roster: committee.roster,
    pmc: !ASF::Committee.nonpmcs.include?(committee)
  }]
}]

# output results
output.puts JSON.pretty_generate(info)
output.close
