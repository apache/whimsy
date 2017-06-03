#
# Monitor status of git updates
#
=begin
Sample input: See DATA section

Output status level can be:
Success - workspace is up to date
Info - one or more files updated
Warning - partial response
Danger - unexpected text in log file

=end

require 'fileutils'

def Monitor.git(previous_status)
  logdir = File.expand_path('../../../logs', __FILE__)
  log = File.join(logdir, 'git-pull')

  archive = File.join(logdir, 'archive')
  FileUtils.mkdir(archive) unless File.directory?(archive)

  # read cron log
  if __FILE__ == $0 # unit test
    fdata = DATA.read
  else
    fdata = File.open(log) {|file| file.flock(File::LOCK_EX); file.read}
  end

  updates = fdata.split(%r{\n(?:/\w+)*/srv/git/})[1..-1]

  status = {}
  seen_level = {}

  # extract status for each repository
  updates.each do |update|
    level = 'success'
    title = nil
    data = revision = update[/^(Already up-to-date.|Updating [0-9a-f]+\.\.[0-9a-f]+)$/]
    show 'data', data

    lines = update.split("\n")
    repository = lines.shift.to_sym
    show 'repository', repository

    start_ignores = [
      'Already ',
      'Your branch is up-to-date with',
      'Your branch is behind',
      '  (use "git pull" ',
      'Fast-forward',
      'Updating ',
    ]
      
    lines.reject! do |line| 
      line.start_with?(*start_ignores) or
      line =~ /^ \d+ files changed, \d+ insertions\(\+\), \d+ deletions\(-\)$/
    end

    unless lines.empty?
      level = 'info'
      data = lines.dup
    end

    # Drop the individual file details
    lines.reject! {|line| line =~  /^ \S+ +\| [ \d]\d /}

    show 'lines', lines
    if lines.empty?
      if not data
        title = "partial response"
        level = 'warning'
        seen_level[level] = true
      elsif String  === data
        title = "No files updated"
      elsif data.length == 1
        title = "1 file updated"
      else
        title = "#{data.length} files updated"
      end

      data << revision if revision and data.instance_of? Array
    else
      level = 'danger'
      data = lines.dup
      seen_level[level] = true
    end

    status[repository] = {level: level, data: data, href: '../logs/svn-update'}
    status[repository][:title] = title if title
  end

  # save as the highest level seen
  %w{danger warning}.each do |lvl|
    if seen_level[lvl]
      # Save a copy of the log; append the severity so can track more problems
      file = File.basename(log)
      if __FILE__ == $0 # unit test
        puts "Would copy log to " + File.join(archive, file + '.' + lvl)
      else
        FileUtils.copy log, File.join(archive, file + '.' + lvl), preserve: true
      end
      break
    end
  end
  
  {data: status}
end

private

def show(name,value)
#  $stderr.puts "#{name}='#{value.to_s}'"
end

# for debugging purposes
if __FILE__ == $0
  require_relative 'unit_test'
  runtest('git') # must agree with method name above
#  DATA.each do |l|
#    puts l
#  end
end

# test data
__END__

/x1/srv/git/infrastructure-puppet
Already on 'deployment'
Your branch is behind 'origin/deployment' by 1 commit, and can be fast-forwarded.
  (use "git pull" to update your local branch)
Updating 74bdd49..83e4220
Fast-forward
 data/ubuntu/1404.yaml                     |  1 +
 data/ubuntu/1604.yaml                     |  1 +
 modules/build_slaves/manifests/jenkins.pp | 38 +++++++++++++++++++-------------------
 3 files changed, 21 insertions(+), 19 deletions(-)

/x1/srv/git/infrastructure-puppet2
Already on 'deployment'
Your branch is up-to-date with 'origin/deployment'.
Already up-to-date.

/x1/srv/git/letsencrypt
Already up-to-date.
