#
# common code for generating public files
#
# This code must be kept in sync with ../status/monitors/public_json.rb or
# else infrastructure alerts will be generated.
#
# Status updates: https://whimsy-test.apache.org/status/
#

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
require 'json'

require 'open3'
require 'wunderbar'

Wunderbar.log_level = 'info' unless Wunderbar.logger.info? # try not to override CLI flags

# Add datestamp to log messages (progname is not needed as each prog has its own logfile)
Wunderbar.logger.formatter = proc { |severity, datetime, _progname, msg|
  "_#{severity} #{datetime} #{msg}\n"
}

# Allow diff output to be suppressed
@noDiff = ARGV.delete '--nodiff'

GITINFO = ASF.library_gitinfo rescue '?'

class ChangeStatus
  UNCHANGED = :unchanged
  CHANGED   = :changed
  NEW       = :new
end

def changed?
  return @changed == ChangeStatus::CHANGED
end

def unchanged?
  return @changed == ChangeStatus::UNCHANGED
end

def new?
  return @changed == ChangeStatus::NEW
end

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

def sendMail(subject, body, to='Notification List <notifications@whimsical.apache.org>')
  require 'whimsy/asf/status'
  unless Status.active?
    Wunderbar.info "Did not detect active status, not sending mail: #{subject}"
    return
  end
  begin
    require 'mail'
    ASF::Mail.configure
    mail = Mail.new do
      from 'Public JSON file updates  <dev@whimsical.apache.org>'
      to to
      subject subject
      body body
    end
    # in spite of what the docs say, this does not seem to work in the body above
    mail.charset = 'utf-8'
    # Replace .mail suffix with more accurate one
    mail.message_id = "<#{Mail.random_tag}@#{::Socket.gethostname}.apache.org>"
    # deliver mail
    mail.deliver!
  rescue StandardError => e
    Wunderbar.warn "sendMail [#{subject}] failed with exception: #{e}"
  end
end

# Massage the strings to drop the timestamps so spurious changes are not reported/saved
def removeTimestamps(s)
  # Drop the first occurrences only (but drop both)
  return s.sub(/  "last_updated": "[^"]+",/, '').sub(/  "code_version": "[^"]+",/, '')
end

# Write formatted output to specific file
def write_output(file, results)

  if not File.exist?(file) or
    (@old_file = File.read(file).chomp; removeTimestamps(@old_file)) != removeTimestamps(results)

    Wunderbar.info "git_info: #{GITINFO} - creating/updating #{file}"

    if File.exist?(file)
      @changed = ChangeStatus::CHANGED
    else
      @changed = ChangeStatus::NEW
    end

    # can get the following error if stdin_data is very large and diff fails with an error
    # before reading all the input, e.g. because the input file is missing:
    #   open3.rb:287:in `write': Broken pipe (Errno::EPIPE)
    # so first check for file present, but also fail gracefully if there is a further issue
    # (if the diff fails we don't want to lose the output entirely)

    if File.exist?(file) and !@noDiff
      begin
        out, err, rc = Open3.capture3('diff', '-u', file, '-',
          stdin_data: results + "\n")
        if err.empty? and rc.exitstatus == 1
          puts "\n#{out}\n"
          ldaphost = ASF::LDAP.host()
          if ldaphost
            body = "\n#{ldaphost}\n\n#{out}\n"
          else
            body = "\n#{out}\n"
          end
          sendMail("Difference(s) in #{file}", body)
        end
      rescue StandardError => e
        Wunderbar.warn "Got exception #{e}"
      end
    end

    # replace file as contents have changed
    File.write(file, results + "\n")

  else

    Wunderbar.info "git_info: #{GITINFO} - no change to #{file}"
    @changed = ChangeStatus::UNCHANGED

  end

end

# for debugging purposes
if __FILE__ == $0
  @noDiff = true
  info = {}
  require 'Tempfile'
  file = Tempfile.new('test.tmp')
  path = file.path
  file.unlink # must not exist originally
  begin
    warn('Expecting create/update')
    public_json_output_file(info, path)
    warn('expecting new', @changed)
    info = {a: 1}
    public_json_output_file(info, path)
    warn('expecting changed', @changed)
    public_json_output_file(info, path)
    warn('expecting unchanged', @changed)
  ensure
    file.close
    file.unlink   # deletes the temp file
  end
end
