#
# Encapsulate access to mailboxes
#

require 'digest'
require 'zlib'
require 'zip'
require 'stringio'
require 'mail'

require_relative 'config.rb'

class Mailbox
  #
  # Initialize a mailbox
  #
  def initialize(name)
    name = File.basename(name, '.yml') if name.end_with? '.yml'

    if name =~ /^\d+$/
      @filename = Dir["#{ARCHIVE}/#{name}", "#{ARCHIVE}/#{name}.gz"].first
    else
      @filename = name
    end
  end

  #
  # Determine whether or not the mailbox exists
  #
  def exist?
    @filename and File.exist?(@filename)
  end

  #
  # Read a mailbox and split it into messages
  #
  def messages
    return @messages if @messages
    return [] unless exist?

    mbox = File.read(@filename)

    if @filename.end_with? '.gz'
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
  def find(hash)
    message = messages.find {|message| Mailbox.hash(message) == hash}
    Mail.new(message) if message
  end

  #
  # iterate through messages
  #
  def each(&block)
    messages.each(&block)
  end

  #
  # return headers
  #
  def headers
    source = File.basename(@filename, '.gz').untaint
    messages = YAML.load_file("#{ARCHIVE}/#{source}.yml") rescue {}
    messages.delete :mtime
    messages.each do |key, value|
      value[:source]=source
    end
  end

  #
  # What to use as a hash for mail
  #
  def self.hash(message)
    Digest::SHA1.hexdigest(message[/^Message-ID:.*/i] || message)[0..9]
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
end
