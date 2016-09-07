#
# Encapsulate access to mailboxes
#

require 'zlib'
require 'zip'
require 'stringio'
require 'yaml'

require_relative '../config.rb'

require_relative 'message.rb'

class Mailbox
  #
  # fetch a/some/all mailboxes
  #
  def self.fetch(mailboxes=nil)
    options = %w(-av --no-motd)

    if mailboxes == nil
      options += %w(--delete --exclude=*.yml --exclude=*.mail)
      source = "#{SOURCE}/"
    elsif Array === mailboxes
      host, path = SOURCE.split(':', 2)
      files = mailboxes.map {|name| "#{path}/#{name}*"}
      source = "#{host}:#{files.join(' ')}"
    else
      source = "#{SOURCE}/#{mailboxes}*"
    end

    Dir.mkdir ARCHIVE unless Dir.exist? ARCHIVE
    system 'rsync', *options, source, "#{ARCHIVE}/"
  end

  #
  # Initialize a mailbox
  #
  def initialize(name)
    name = File.basename(name, '.yml')

    if name =~ /^\d+$/
      @name = name.untaint
      @mbox = Dir["#{ARCHIVE}/#{@name}", "#{ARCHIVE}/#{@name}.gz"].first.untaint
    else
      @name = name.split('.').first
      @mbox = "#{ARCHIVE}/#{name}"
    end
  end

  #
  # convenience interface to update
  #
  def self.update(name, &block)
    Mailbox.new(name).update(&block)
  end

  #
  # encapsulate updates to a mailbox
  #
  def update
    File.open(yaml_file, File::RDWR|File::CREAT, 0644) do |file| 
      file.flock(File::LOCK_EX)
      mbox = YAML.load(file.read) || {} rescue {}
      yield mbox
      file.rewind
      file.write YAML.dump(mbox)
      file.truncate(file.pos)
    end
  end

  #
  # Read a mailbox and split it into messages
  #
  def messages
    return @messages if @messages
    return [] unless @mbox and File.exist?(@mbox)

    mbox = File.read(@mbox)

    if @mbox.end_with? '.gz'
      stream = StringIO.new(mbox)
      reader = Zlib::GzipReader.new(stream)
      mbox = reader.read
      reader.close
      stream.close rescue nil
    end

    mbox.force_encoding Encoding::ASCII_8BIT

    # split into individual messages
    @messages = mbox.split(/^From .*/)
    @messages.shift

    @messages
  end

  #
  # Find a message
  #
  def self.find(message)
    month, hash = message.match(%r{/(\d+)/(\w+)}).captures
    Mailbox.new(month.untaint).find(hash.untaint)
  end

  #
  # Find a message
  #
  def find(hash)
    headers = YAML.load_file(yaml_file) rescue {}

    if Dir.exist? dir and File.exist? File.join(dir, hash)
      email = File.read(File.join(dir, hash), encoding: Encoding::BINARY)
    else
      email = messages.find {|message| Message.hash(message) == hash}
    end

    Message.new(self, hash, headers[hash], email) if email
  end

  #
  # iterate through messages
  #
  def each(&block)
    messages.each(&block)
  end

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

  #
  # return headers (server view)
  #
  def headers
    messages = YAML.load_file(yaml_file) rescue {}
    messages.delete :mtime
    messages.each do |key, value|
      value[:source]=@name
    end
  end

  #
  # return headers (client view)
  #
  def client_headers
    # fetch a list of headers for all messages in the maibox with attachments
    headers = self.headers.to_a.select do |id, message|
      message[:attachments]
    end

    # extract relevant fields from the headers
    headers.map! do |id, message|
      {
        time: message[:time],
        href: "#{message[:source]}/#{id}/",
        from: message[:from],
        subject: message['Subject'],
        status: message[:status]
      }
    end

    # return messages sorted in reverse chronological order
    headers.sort_by {|message| message[:time]}.reverse
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

  #
  # parse a mailbox, updating YAML
  #
  def parse
    return unless @mbox
    mbox = YAML.load_file(yaml_file) || {} rescue {}
    return if mbox[:mtime] == File.mtime(@mbox)

    # open the YAML file for real (locking it this time)
    self.update do |mbox|
      mbox[:mtime] = File.mtime(@mbox)

      # process each message in the mailbox
      self.each do |message|
        # compute id, skip if already processed
        id = Message.hash(message)
        mbox[id] ||= Message.parse(message)
      end
    end
  end
end
