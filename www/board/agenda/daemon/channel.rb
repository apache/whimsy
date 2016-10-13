#
# Maintain two lists of active sockets (channels): one associating a user
# with a list of sockets, and one associating each socket to a single user.
#

require 'json'
require 'concurrent'

class Channel
  @@sockets = Concurrent::Map.new
  @@users = Concurrent::Map.new {|map,key| map[key]=[]}

  # add a new socket/userid pair
  def self.add(ws, id)
    if @@users[id].empty?
      self.post_all(type: :arrive, user: id, present: self.present,
        timestamp: Time.now.to_f*1000)
    end
    @@users[id] << ws
    @@sockets[ws] = id
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
    @@users.keys
  end

  # close all open sockets
  def self.close_all
    @@sockets.keys.each do |client|
      client.close
    end
  end
end
