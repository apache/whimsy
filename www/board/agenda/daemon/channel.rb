#
# Maintain two lists of active sockets (channels): one associating a user
# with a list of sockets, and one associating each socket to a single user.
#

require 'json'
require 'concurrent'
require 'listen'
require 'digest'
require 'yaml'

require_relative './session'
require_relative './events'
require 'whimsy/asf/svn'

class Channel
  @@sockets = Concurrent::Map.new
  @@users = Concurrent::Map.new {|map,key| map.compute_if_absent(key) { [] } }

  begin
    FOUNDATION_BOARD = ASF::SVN['foundation_board']
  rescue Exception
    # rescue value is to help with startup when initialising a new host
    FOUNDATION_BOARD = '/srv/svn/foundation_board'
  end

  # add a new socket/userid pair
  def self.add(ws, id)
    @@users[id] << ws
    @@sockets[ws] = id
    if @@users[id].length == 1
      self.post_all(type: :arrive, user: id, present: self.present,
        timestamp: Time.now.to_f*1000)
    end
  end

  # send a message to a list of clients
  def self.post(clients, msg)
    clients.each do |client|
      EM.defer(
        ->() {client.send msg},
        ->(response) {},
        ->(error) {client.close rescue nil}
      )
    end
  end

  # send a message to all users
  def self.post_all(msg)
    msg = JSON.dump(msg) if msg.instance_of? Hash
    self.post @@sockets.keys, msg
  end

  # send a message to a specific user
  def self.post_private(user, msg)
    msg = JSON.dump(msg) if msg.instance_of? Hash
    self.post @@users[user] || [], msg
  end

  # delete a socket connection
  def self.delete(ws)
    id = @@sockets.delete(ws)
    if id
      @@users[id].delete ws
      if @@users[id].empty?
        @@users.delete id
        self.post_all(type: :depart, user: id, present: self.present,
          timestamp: Time.now.to_f*1000)
      end
    end
  end

  # return a list of active users
  def self.present
    users = @@users.keys
    path = File.join(Session::WORKDIR, 'present.yml')

    File.open(path, File::RDWR|File::CREAT, 0644) do |fh|
      fh.flock(File::LOCK_EX)
      fh.write(YAML.dump(users))
      fh.flush
      fh.truncate(fh.pos)
    end

    users.reject {|name| name =~ /^board_agenda_[_\d]+$/}
  end

  # close all open sockets
  def self.close_all
    @@sockets.each_key do |client|
      client.close
    end
  end

  # listen for changes to agenda files
  board_listener = Listen.to(FOUNDATION_BOARD) do |modified, added, removed|
    modified.each do |path|
      next unless File.exist?(path)
      file = File.basename(path)
      if file =~ /^board_agenda_[\d_]+.txt$/
        contents = File.read(path)
        digest = Digest::SHA256.base64digest(contents)
        self.post_all type: :agenda, file: file, digest: digest
      end
    end
  end

  board_listener.start

  # listen for changes to pending and minutes files
  work_listener = Listen.to(Session::AGENDA_WORK) do |modified, added, removed|
    (modified+added).each do |path|
      next if path.end_with? '/sessions/present.yml'
      next unless File.exist?(path)
      file = File.basename(path)
      if path =~ /board_agenda_\d+_\d+_\d+.txt$/
        contents = File.read(path)
        digest = Digest::SHA256.base64digest(contents)
        self.post_all type: :agenda, file: file, digest: digest
      elsif file =~ /^board_minutes_\d{4}_\d\d_\d\d\.yml$/
        agenda = file.sub('minutes', 'agenda').sub('.yml', '.txt')
        self.post_all type: :minutes, agenda: agenda,
          value: YAML.load_file(path)
      elsif file =~ /^(\w+)\.yml$/
        self.post_private $1, type: :pending, private: $1,
          value: YAML.load_file(path)
      elsif path =~ /\/events\/\w+$/
        Events.process()
      elsif file =~ /^(\w+)\.bak$/
        nil
      elsif path =~ /^\/sessions\/\w+$/
        nil
      elsif file =~ /^board_agenda_\d{4}_\d\d_\d\d\-chat.yml$/
        nil
      else
        STDERR.puts path
      end
    end
  end

  work_listener.start

  # process pending messages
  Events.process()
end
