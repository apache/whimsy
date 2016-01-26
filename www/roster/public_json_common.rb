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

    puts "_INFO git_info: #{GITINFO}"

    # can get the following error if stdin_data is very large and diff fails with an error
    # before reading all the input, e.g. because the input file is missing:
    #   open3.rb:287:in `write': Broken pipe (Errno::EPIPE)
    # so first check for file present, but also fail gracefully if there is a further issue
    # (if the diff fails we don't want to lose the output entirely)

    if File.exist?(ARGV.first)
      begin
        out, err, rc = Open3.capture3('diff', '-u', ARGV.first, '-',
          stdin_data: results + "\n")
        puts "\n#{out}\n" if err.empty? and rc.exitstatus == 1
        rescue
          # ignore failure here
      end
    end

    # replace file as contents have changed
    File.write(ARGV.first, results + "\n")

  else

    puts "_INFO git_info: #{GITINFO}"

  end
end
