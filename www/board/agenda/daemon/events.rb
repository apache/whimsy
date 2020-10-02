require 'fileutils'
require 'json'
require 'securerandom'

require 'whimsy/asf/config'

#
# Low-tech, file based event manager.  Each message is stored as a separate
# file on disk, and is deleted once processed.
#
# No direct use of timers, events, or threads are made allowing this
# service to be used in a variety of contexts (e.g. Sinatra and
# EventMachine).
#

class Events
  if ENV['RACK_ENV'] == 'test'
    AGENDA_WORK = File.expand_path('test/work/data')
  else
    AGENDA_WORK = ASF::Config.get(:agenda_work) || '/srv/agenda'
  end

  WORKDIR = File.expand_path('events', AGENDA_WORK)

  # capture a message to be sent
  def self.post(message)
    FileUtils.mkdir_p WORKDIR
    filename = SecureRandom.hex(16)
    File.write(File.join(WORKDIR, filename), JSON.generate(message))
    message
  end

  # process pending messages
  def self.process()
    Dir[File.join(WORKDIR, '*')].each do |file|
      begin
        message = JSON.parse(File.read(file))
        if message[:private]
          Channel.post_private(message[:private], message)
        else
          Channel.post_all(message)
        end
      ensure
        File.unlink file
      end
    end
  end
end
