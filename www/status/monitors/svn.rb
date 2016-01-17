#
# Monitor status of svn updates
#

def Monitor.svn(previous_status)
  # read cron log
  log = File.expand_path('../../www/logs/svn-update')
  updates = File.read(log).split("\n/srv/svn/")
  updates.shift

  status = {}

  # extract status for each repository
  updates.each do |update|
    level = 'success'
    data = update[/^At revision \d+\.$/]

    lines = update.split("\n")
    repository = lines.shift

    lines.reject! {|line| line == "Updating '.':"}
    lines.reject! {|line| line =~ /^At revision \d+\.$/}

    unless lines.empty?
      level = 'info'
      data = lines.dup
    end

    lines.reject! {|line| line =~ /^[ADU]    /}

    unless lines.empty?
      level = 'danger'
      data = lines.dup
    end

    status[repository] = {level: level, data: data}
  end

  {data: status}
end
