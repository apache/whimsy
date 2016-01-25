#
# common code for generating public files
#
# This code must be kept in sync with ../status/monitors/public_json.rb or
# else infrastructure alerts will be generated.
#
# Status updates: https://whimsy-test.apache.org/status/
#

require 'bundler/setup'

require 'whimsy/asf'
require 'json'

require 'open3'

GITINFO = ASF.library_gitinfo rescue '?'

def public_json_output(info)
  # format as JSON
  results = JSON.pretty_generate(info)

  # parse arguments for output file name
  if ARGV.length == 0 or ARGV.first == '-'

    # write to STDOUT
    puts results

  elsif not File.exist?(ARGV.first) or File.read(ARGV.first).chomp != results

    puts "git_info: #{GITINFO}"

    out, err, rc = Open3.capture3('diff', '-u', ARGV.first, '-',
      stdin_data: results + "\n")
    puts "\n#{out}\n" if err.empty? and rc.exitstatus == 1

    # replace file as contents have changed
    File.write(ARGV.first, results + "\n")

  else

    puts "git_info: #{GITINFO}"

  end
end
