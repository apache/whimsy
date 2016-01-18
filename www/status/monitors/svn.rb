#
# Monitor status of svn updates
#

def Monitor.svn(previous_status)
  # read cron log
  log = File.expand_path('../../../logs/svn-update', __FILE__)
  data = File.open(log) {|file| file.flock(File::LOCK_EX); file.read}
  updates = data.split("\n/srv/svn/")[1..-1]

  status = {}

  # extract status for each repository
  updates.each do |update|
    level = 'success'
    title = nil
    data = revision = update[/^(Updated to|At) revision \d+\.$/]

    lines = update.split("\n")
    repository = lines.shift

    lines.reject! {|line| line == "Updating '.':"}
    lines.reject! {|line| line =~ /^(Updated to|At) revision \d+\.$/}

    unless lines.empty?
      level = 'info'
      data = lines.dup
    end

    lines.reject! {|line| line =~ /^[ADU]    /}

    if lines.empty?
      if not data
        title = "partial response"
        level = 'warning'
      elsif data.length == 1
        title = "1 file updated"
      else
        title = "#{data.length} files updated"
      end

      data << revision if data.instance_of? Array
    else
      level = 'danger'
      data = lines.dup
    end

    status[repository] = {level: level, data: data, href: '../logs/svn-update'}
    status[repository][:title] = title if title
  end

  {data: status}
end
