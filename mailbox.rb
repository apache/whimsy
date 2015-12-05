require 'digest'
require 'zlib'
require 'zip'
require 'stringio'
require 'mail'

require_relative 'config.rb'

class Mailbox
  #
  # Read a mailbox and split it into messages
  #
  def initialize(filename)
    mails = File.read(filename)

    if filename.end_with? '.gz'
      stream = StringIO.new(mails)
      reader = Zlib::GzipReader.new(stream)
      mails = reader.read
      reader.close
      stream.close rescue nil
    end

    mails.force_encoding Encoding::ASCII_8BIT

    # split into individual messages
    mails = mails.split(/^From .*/)
    mails.shift

    @mails = mails
  end

  #
  # Find a message
  #
  def find(hash)
    message = @mails.find {|mail| Mailbox.hash(mail) == hash}
    Mail.new(message) if message
  end

  #
  # iterate through messages
  #
  def each(&block)
    @mails.each(&block)
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
