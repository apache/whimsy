#
# common code for generating public files
#
# This code must be kept in sync with ../status/monitors/public_json.rb or
# else infrastructure alerts will be generated.
#
# Status updates: https://whimsy-test.apache.org/status/
#

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'whimsy/asf'
require 'json'

require 'open3'
require 'wunderbar'

Wunderbar.log_level = 'info' unless Wunderbar.logger.info? # try not to override CLI flags

# Add datestamp to log messages (progname is not needed as each prog has its own logfile)
Wunderbar.logger.formatter = proc { |severity, datetime, progname, msg|
      "_#{severity} #{datetime} #{msg}\n"
    }

# Allow diff output to be suppressed
@noDiff = ARGV.delete '--nodiff'

GITINFO = ASF.library_gitinfo rescue '?'

# Pretty-prints the JSON input and writes it to the output.
# If the output is not STDOUT, then it is checked to see
# if it has changed. If not, the output file is not touched.
# If it has changed, the file is rewritten, and the diffs
# are obtained and written to STDOUT.
# The method logs whether the output file has been created/updated
# or is unchanged.
# No log messages are generated if no output file was specified.
# Params:
# +info+:: JSON hash to be written
def public_json_output(info)
  # format as JSON
  results = JSON.pretty_generate(info)

  # parse arguments for output file name
  if ARGV.length == 0 or ARGV.first == '-'

    # write to STDOUT
    puts results

  else

    write_output(ARGV.first, results)

  end

end

# Format and write output to specific file
def public_json_output_file(info, file)
  # format as JSON
  results = JSON.pretty_generate(info)

  write_output(file, results)

end

# Write formatted output to specific file
def write_output(file, results)

  if not File.exist?(file) or File.read(file).chomp != results

    Wunderbar.info "git_info: #{GITINFO} - creating/updating #{file}"

    # can get the following error if stdin_data is very large and diff fails with an error
    # before reading all the input, e.g. because the input file is missing:
    #   open3.rb:287:in `write': Broken pipe (Errno::EPIPE)
    # so first check for file present, but also fail gracefully if there is a further issue
    # (if the diff fails we don't want to lose the output entirely)

    if File.exist?(file) and ! @noDiff
      begin
        out, err, rc = Open3.capture3('diff', '-u', file, '-',
          stdin_data: results + "\n")
        if err.empty? and rc.exitstatus == 1
          puts "\n#{out}\n"
          require 'mail'
          ASF::Mail.configure
          mail = Mail.new do
            from 'dev@whimsical.apache.org'
            to 'sebb@apache.org' # For testing purposes, will be changed to notifications@whimsical.a.o
            subject "Difference(s) in #{file}"
            body "\n#{out}\n"
          end
          # deliver mail
          mail.deliver!
        end
      rescue
        # ignore failure here
      end
    end
  
    # replace file as contents have changed
    File.write(file, results + "\n")

  else
  
    Wunderbar.info "git_info: #{GITINFO} - no change to #{file}"
  
  end

end
