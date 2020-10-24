require 'fileutils'
require 'thread'
require 'securerandom'
require 'concurrent'

require 'whimsy/asf/config'

#
# Low-tech, file based session manager.  Each session is stored as a separate
# file on disk, and expires after two days.  Each request for a new session
# is guaranteed to return a session with a minimum of a day left before
# expiring.
#
# Concurrent::Map provides thread safe access to data; a mutex is used
# to additionally prevent concurrent updates.
#
# No direct use of timers, events, or threads are made allowing this
# service to be used in a variety of contexts (e.g. Sinatra and
# EventMachine).
#

class Session
  if ENV['RACK_ENV'] == 'test'
    AGENDA_WORK = File.expand_path('test/work/data')
  else
    AGENDA_WORK = ASF::Config.get(:agenda_work) || '/srv/agenda'
  end

  WORKDIR = File.expand_path('sessions', AGENDA_WORK)
  DAY = 24*60*60 # seconds

  @@sessions = Concurrent::Map.new
  @@users = Concurrent::Map.new {|map,key| map[key]=[]}

  @@semaphore = Mutex.new

  # find the latest session for the given user, creating one if necessary.
  def self.user(id)
    session = @@users[id].max_by {|session| session[:mtime]}
    session = nil if session and session[:mtime] < Time.now - DAY

    # if not found, try refreshing data from disk and try again
    if not session
      Session.load
      session = @@users[id].max_by {|session| session[:mtime]}
      session = nil if session and session[:mtime] < Time.now - DAY
    end

    # if still not found, generate a new session
    if not session
      @@semaphore.synchronize do
        secret = SecureRandom.hex(16)
        file = File.join(WORKDIR, secret)
        File.write(file, id)
        session = {id: id, secret: secret, mtime: File.mtime(file)}
        @@sessions[secret] = session
        @@users[id] << session
      end
    end

    # return the secret
    session[:secret]
  end

  # retrieve session for a given secret
  def self.[](secret)
    session = @@sessions[secret]

    # if not found, try refreshing data from disk and try again
    if not session
      Session.load
      session = @@sessions[secret]
    end

    session
  end

  # load sessions from disk
  def self.load(files=nil)
    @@semaphore.synchronize do
      # default files to all files in the workdir and @@sessions hash
      files ||= Dir["#{WORKDIR}/*"] +
        @@sessions.keys.map {|secret| File.join(WORKDIR, secret)}

      files.uniq.each do |file|
        next if file =~ /\.yml$/
        secret = File.basename(file)
        session = @@sessions[secret]

        if File.exist?(file) and File.writable?(file)
          if File.mtime(file) < Time.now - 2 * DAY
            begin
              File.delete file
            rescue RuntimeError => error
              STDERR.puts "Error deleting #{file}: #{error}"
            end
          else
            # update class variables if the file changed
            mtime = File.mtime(file)
            next if session and session[:mtime] == mtime

            session = {id: File.read(file), secret: secret, mtime: mtime}
            @@sessions[secret] = session
            @@users[session[:id]] << session
          end
        else
          # remove session if the file no longer exists
          @@users[session[:id]].delete(session) if session
          @@sessions.delete(secret)
        end
      end
    end
  end

  # ensure the working directory exists
  FileUtils.mkdir_p WORKDIR

  # load initial data from disk
  self.load
end
