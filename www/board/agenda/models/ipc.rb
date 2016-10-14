require 'yaml'

module IPC

  if Dir.exist? '/etc/letsencrypt'
    @@url ="wss://127.0.0.1:34234"
  else
    @@url ="ws://127.0.0.1:34234"
  end

  def self.post(data)
    thread = Thread.new do
      # post to web socket server
      ws = WebSocket::Client::Simple.connect @@url

      begin
        done = false
        ws.on :open do
          if data[:private]
            headers = "session: #{data[:private]}\n\n"
          else
            headers = ''
          end

          ws.send headers + JSON.dump(data)
          done = true
        end

        sleep 0.1 until done
      ensure
        ws.close
      end
    end
  end

  @@present = []
  @@mtime = nil
  def self.present
    file = File.join(AGENDA_WORK, 'sessions', 'present.yml')
    if not File.exist?(file) or File.mtime(file) == @@mtime
      @@present
    else
      @@mtime = File.mtime(file)
      @@present = YAML.load_file(file)
    end
  end
end
