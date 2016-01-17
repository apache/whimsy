#
# Monitor status of public json directory
#

def Monitor.public_json(previous_status)
  logs = File.expand_path('../../www/logs/public-*')

  status = {}

  Dir[logs].each do |log|
    name = File.basename(log).sub('public-', '')

    if File.size(log) == 0
      status[name] = {data: "Last updated #{File.mtime(log)}"}
    else
      status[name] = {level: 'danger', data: File.readlines(log)}
    end
  end

  {data: status}
end
