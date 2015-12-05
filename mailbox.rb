require 'digest'
require 'zlib'
require 'zip'
require 'stringio'
require 'mail'

require_relative 'config.rb'

class Mailbox
  #
  # What to use as a hash for mail
  #
  def self.hash(message)
    Digest::SHA1.hexdigest(message[/^Message-ID:.*/i] || message)[0..9]
  end

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
end


