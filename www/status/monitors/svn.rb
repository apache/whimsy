#
# Monitor status of svn updates
#
=begin
Sample input:
See DATA section after __END__

Output status level can be:
Success - workspace is up to date
Info - one or more files updated
Warning - partial response
Danger - unexpected text in log file

=end

require 'fileutils'

# Match revision messages
REV_RE = %r{^(Checked out|\s*Updated ('[^']+' )?to|At|List updated from \d+ to|List is at) (revision |r)\d+\s*\.$}

def Monitor.svn(previous_status)
  logdir = File.expand_path('../../../logs', __FILE__)
  archive = File.join(logdir,'archive')
  FileUtils.mkdir(archive) unless File.directory?(archive)

  # read cron log
  if $0 == __FILE__ and ARGV.first == '__DATA__'
    log = nil
    fdata = DATA.read
  else
    log = File.expand_path('../../../logs/svn-update', __FILE__)
    fdata = File.open(log) {|file| file.flock(File::LOCK_EX); file.read}
  end
  updates = fdata.split(%r{\n(?:/\w+)*/srv/svn/})[1..-1]

  status = {}
  seen_level = {}

  # extract status for each repository
  updates.each do |update|
    level = 'success'
    title = nil
    data = revision = update[REV_RE] # String.is_a? data

    lines = update.split("\n")
    repository = lines.shift.to_sym

    lines.reject! do |line|
      line =~ %r{Updating '.+':} or
      line == "Summary of updates:" or
      # must agree with Rakefile/PREFIX
      line.start_with?('#!: ') or
      line =~ REV_RE # this was processed above
    end

    unless lines.empty?
      level = 'info'
      data = lines.dup # array
    end

    lines.reject! {|line| line =~ /^([ADU] |[ U]U)   /}

    if lines.empty?
      if not data
        title = "partial response"
        level = 'warning'
        seen_level[level] = true
      elsif data.is_a? String # only saw revision message
        title = "No files updated"
      elsif data.length == 1
        title = "1 file updated"
      else
        title = "#{data.length} files updated"
      end

      data << revision if revision and data.instance_of? Array
    else
      next if lines == ['Skipping']
      level = 'danger'
      data = lines.dup
      seen_level[level] = true
    end

    status[repository] = {level: level, data: data, href: '../logs/svn-update'}
    status[repository][:title] = title if title
  end

  # save as the highest level seen
  %w{danger warning}.each do |lvl|
    if seen_level[lvl] and log
      # Save a copy of the log; append the severity so can track more problems
      file = File.basename(log)
      FileUtils.copy log, File.join(archive, file + '.' + lvl), preserve: true
      break
    end
  end

  {data: status}
end

# for debugging purposes
if __FILE__ == $0
  if ARGV.first == '__DATA__'
    response = Monitor.svn(nil) # must agree with method name above
    data = response[:data]
    data.each do |k,v|
      puts "#{k} #{data[k][:level]} #{data[k][:title]} #{data[k][:data]}"
    end
  else
    require_relative 'unit_test'
    runtest('svn') # must agree with method name above
  end
end

# test data
__END__

/srv/svn/Bills
Skipping

/srv/svn/cclas
#!: Updating listing file
List updated from 0 to revision 93888  .

/srv/svn/iclas
#!: Updating listing file
List is at revision 93865.

/srv/svn/Meetings
Updating '.':
At revision 67610.

/srv/svn/site-root
Updating '.':
U    index.html
Updated to revision 1797393.

/srv/svn/site-root
A    site-root/extpaths.txt
 U   site-root
Checked out revision 1797381.

/x1/srv/svn/personnel-duties
Updating '.':
svn: E175002: Unexpected HTTP status 400 'Bad Request' on '/repos/private/!svn/rvr/76960/foundation/officers/personnel-duties'

/x1/srv/svn/personnel-duties
#!: failed!
#!: Updating '.':
#!: svn: E175002: Unexpected HTTP status 400 'Bad Request' on '/repos/private/!svn/rvr/76960/foundation/officers/personnel-duties'
#!: will retry in 10 seconds
Updating '.':
svn: E175002: Unexpected HTTP status 400 'Bad Request' on '/repos/private/!svn/rvr/76960/foundation/officers/personnel-duties'
Updated to revision 1797393.

/srv/svn/qmail_control1
#!: svn update badrcptto badrcptto_patterns
Updating 'badrcptto':
At revision 1053537.
Updating 'badrcptto_patterns':
At revision 1053537.
Summary of updates:
  Updated 'badrcptto' to r1053537.
  Updated 'badrcptto_patterns' to r1053537.

/srv/svn/qmail_control2
#!: update depth from 'files' to 'empty'
D         badheaders
D         badheaders.new
D         badheaderthresh
D         badmailfrom
D         badrcptto
D         badrcptto_patterns
D         concurrencylocal
D         concurrencyremote
D         defaultdelivery
D         defaultdomain
D         doublebounceto
D         helohost
D         locals
D         me
D         me.asf
D         newsmtp
D         plusdomain
D         queuelifetime
D         rcpthosts
D         rcpthosts.asf
D         signatures
D         smtproutes
D         timeoutconnect
D         timeoutremote
D         timeoutsmtpd
D         virtualdomains
Updating '.':
Updated to revision 1053537.
#!: svn update badrcptto badrcptto_patterns
Updating 'badrcptto':
A    badrcptto
Updated to revision 1053537.
Updating 'badrcptto_patterns':
A    badrcptto_patterns
Updated to revision 1053537.
Summary of updates:
  Updated 'badrcptto' to r1053537.
  Updated 'badrcptto_patterns' to r1053537.

/srv/svn/qmail_control3
Checked out revision 1053537.
Updating 'badrcptto':
A    badrcptto
Updated to revision 1053537.
Updating 'badrcptto_patterns':
A    badrcptto_patterns
Updated to revision 1053537.
Summary of updates:
  Updated 'badrcptto' to r1053537.
  Updated 'badrcptto_patterns' to r1053537.
