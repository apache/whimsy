#
# Monitor status of public json directory
#

def Monitor.public_json(previous_status)
  logs = File.expand_path('../../www/logs/public-*')

  status = {}

  Dir[logs].each do |log|
    name = File.basename(log).sub('public-', '')

    status[name] = {
      href: "../logs/#{File.basename(log)}",
      mtime: File.mtime(log)
    }

    if File.size(log) != 0
      if File.read(log).start_with? '--- '
        status[name].merge! level: 'info', title: 'updated'
      else
        status[name].merge! level: 'danger', data: File.readlines(log)
      end
    end

  end


  {data: status}
end
