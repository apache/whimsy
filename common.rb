require 'digest'
require 'zlib'
require 'zip'
require 'stringio'

require_relative 'config.rb'

#
# What to use as a hash for mail
#
def hashmail(message)
  Digest::SHA1.hexdigest(mail[/^Message-ID:.*/i] || mail)[0..9]
end

#
# Read a mailbox and split it into messages
#
def readmbox(filename)
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

  mails
end

