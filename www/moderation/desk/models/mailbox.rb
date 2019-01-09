#
# Encapsulate access to mailboxes
#

# It may be necessary to use a database rather than files, so try to avoid exposing
# any of the internal storage details

require 'zlib'
require 'zip'
require 'stringio'
require 'yaml'

require_relative '../config.rb'

require_relative 'message.rb'

class Mailbox

  #
  # Initialize a mailbox
  #
  def initialize(name)
    name = File.basename(name, '.yml')

    if name =~ /^#{MBOX_RE}$/
      @name = name.untaint
      @mbox = Dir["#{ARCHIVE}/#{@name}", "#{ARCHIVE}/#{@name}.gz"].first.untaint
    else
      @name = name.split('.').first
      @mbox = "#{ARCHIVE}/#{name}"
    end
  end

  # centralise the name generation
  def self.mboxname(timestamp=nil)
    # If nil, return the current (last) box (could perhaps be the first)
    Time.at(timestamp||Time.now).gmtime.strftime('%Y%m%d') 
  end

  #
  # convenience interface to update status
  #
  def self.status!(name, hash, newstatus)
    success = false
    Mailbox.new(name).update do |headers|
      target = headers[hash]
      return unless Mailbox.message_visible?(target) # TODO should this throw?
      if target
        # TODO don't allow same message to be counted twice (perhaps store ids in spam lists)
        # TODO capture spammy headers if marking as spam
        # TODO skip update if no record found or no change made
#        if newstatus == :spam
#        end
        target[:status] = newstatus
        success = true
      end
    end
    success # let caller know
  end

  #
  # Allow update of entry using hash
  #
  def self.patch!(name, hash, updates)
    success = false
    Mailbox.new(name).update do |headers|
      target = headers[hash]
      return unless Mailbox.message_visible?(target) # TODO should this throw?
      if target
        # special processing for entries which use symbols as keys
        # (allow for :status not present)
        [target.keys,:status].flatten.each do |key|
          if Symbol === key and updates.has_key? key.to_s
            target[key] = updates.delete(key.to_s) # apply the change and drop from input
          end
        end
  
        target.merge! updates # anything else can just be merged
        success = true
      end
    end
    success # let caller know
  end

  def write_email(hash, email)
    Dir.mkdir dir, 0755 unless Dir.exist? dir
    File.write File.join(dir, hash), email, encoding: Encoding::BINARY
  end

  def write_headers(hash, headers)
    update do |yaml|
      # TODO check if hash exists and throw if so?
      # (would need to override this for testing)
      yaml[hash] = headers
    end
  end

  #
  # encapsulate updates to a mailbox
  # TODO would like to make this private/protected to avoid external updates
  def update
    File.open(yaml_file, File::RDWR|File::CREAT, 0644) do |file| 
      file.flock(File::LOCK_EX)
      mbox = YAML.load(file.read) || {} rescue {}
      yield mbox # TODO allow block to cancel update
      file.rewind
      file.write YAML.dump(mbox)
      file.truncate(file.pos)
    end
  end

  #
  # Find a message by id e.g. yyyymmdd/abcdefgh (for use by GUI)
  # Returns nil if not found or no access
  def self.find(id)
    return unless id
    # Allow leading and trailing slash
    id.match(%r{^/?(#{MBOX_RE})/(#{HASH_RE})/?$}) do |m|
      mbox, hash = m.captures
      Mailbox.new(mbox.untaint).find(hash.untaint)
    end
  end

  
  #
  # Find headers by id e.g. yyyymmdd/abcdefgh (for use by GUI)
  # Returns nil if not found or no access
  def self.hdrs(id)
    return unless id
    # Allow leading and trailing slash
    id.match(%r{^/?(#{MBOX_RE})/(#{HASH_RE})/?$}) do |m|
      mbox, hash = m.captures
      Mailbox.new(mbox.untaint).headers(hash.untaint)
    end
  end
  
  #
  # Find message headers
  #
  def headers(hash)
    headers = YAML.load_file(yaml_file) rescue return
    target = headers[hash]
    return unless Mailbox.message_visible? target # don't allow access to private data
    target
  end

  #
  # Find a message
  #
  def find(hash)
    headers = YAML.load_file(yaml_file) rescue {}
    return unless Mailbox.message_visible? headers[hash] # don't allow access to private data

    file = File.join(dir, hash) 
    # TODO why check the dir?
    if Dir.exist? dir and File.exist? file
      email = File.read(file, encoding: Encoding::BINARY)
    end

    Message.new(self, hash, headers[hash], email) if email
  end
  

  #
  # Find the source message; return the raw data
  #
  def orig(hash)
    headers = YAML.load_file(yaml_file) rescue {}
    return unless Mailbox.message_visible? headers[hash] # don't allow access to private data
 
    file = File.join(dir, hash + '.orig') 
    File.read(file, encoding: Encoding::BINARY) if File.exist? file
  end

  # Is the list wanted by the caller?
  def list_wanted?(message)
    true
  end

  # Is the message visible to the caller?
  # e.g. private and security lists are generally not visible to all
  def self.message_visible?(message)
    message and not %w(private security).include? message[:list] # TODO this is just a test
  end

  def message_active?(status)
    status == nil or status == ''
  end

  #
  # return headers (client view)
  #
  def client_headers
    # fetch a list of headers for all messages in the mailbox
    messages = YAML.load_file(yaml_file) rescue {}
    headers = messages.to_a.select do |id, message|
      message_active?(message[:status]) && Mailbox.message_visible?(message) && list_wanted?(message)
    end

    # extract relevant fields from the headers
    headers.map! do |id, message|
      {
        id: id,
        timestamp: message[:timestamp],
        list: message[:list],
        domain: message[:domain],
        allow: message[:allow],
        accept: message[:accept],
        reject: message[:reject],
        return_path: message['Return-Path'],
        from: message['From'],
        subject: message['Subject'],
        status: message[:status],
        date: message['Date'] || '',
      }
    end

    # Look for next box (currently previous day)
    # TODO no need to do this for events where a box has been updated
    nextmbox = nil
    # find the most recent 10 daily files
    available = Dir["#{ARCHIVE}/*.yml"].map{|f| File.basename(f, '.yml')}.select{|f| f =~ %r{^#{MBOX_RE}$}}.sort.reverse[0..9]
    index = available.find_index {|e| e < @name} # next oldest date from current
    if index
        nextmbox = available[index].untaint
    end

    {
      nextmbox: nextmbox,
      source: @name, # Same for all headers
      headers: headers,
    }
  end

  #
  # common header logic for messages and attachments
  #
  def self.headers(part)
    # extract all fields from the mail (recovering from bad encoding issues)
    fields = part.header_fields.map do |field|
      begin
        next [field.name, field.to_s] if field.to_s.valid_encoding?
      rescue
      end

      if field.value and field.value.valid_encoding?
        [field.name, field.value]
      else
        [field.name, field.value.inspect]
      end
    end

    # group fields by name
    fields = fields.group_by(&:first).map do |name, values|
      if values.length == 1
        [name, values.first.last]
      else
        [name, values.map(&:last)]
      end
    end

    # return fields as a Hash
    Hash[fields]
  end

  private # these methods expose details of the storage

  #
  # name of associated yaml file
  #
  def yaml_file
    "#{ARCHIVE}/#{@name}.yml"
  end
  
  #
  # name of associated directory
  #
  def dir
    "#{ARCHIVE}/#{@name}.mail"
  end

end
