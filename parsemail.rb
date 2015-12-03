#!/usr/bin/ruby

#
# Parse (and optionally fetch) officer-secretary emails for later
# processing.
#
# Care is taken to recover from improperly formed emails, including:
#   * Malformed message ids
#   * Improper encoding
#   * Invalid from addresses
#

require 'mail'
require 'zlib'
require 'zip'
require 'yaml'
require 'stringio'
require 'time'

require_relative 'config'

database = File.basename(SOURCE)

Dir.chdir File.dirname(File.expand_path(__FILE__))

if ARGV.include? '--fetch' or not Dir.exist? database
  system "rsync -av --no-motd --delete --exclude='*.yml' #{SOURCE}/ #{ARCHIVE}/"
end

# common header logic for messages and attachments
def headers(part)
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

# scan each mailbox for updates
width = 0
Dir[File.join(database, '2*')].sort.each do |name|
  # skip YAML files, update output showing latest file being processed
  next if name.end_with? '.yml'
  print "#{name.ljust(width)}\r"
  width = name.length
  
  # test read the YAML file to see if the mbox needs to be parsed
  yaml = File.join(database, File.basename(name)[/\d+/] + '.yml')
  mbox = YAML.load_file(yaml) || {} rescue {}
  next if mbox[:mtime] == File.mtime(name)

  # open the YAML file for real (locking it this time)
  File.open(yaml, File::RDWR|File::CREAT, 0644) do |file| 
    file.flock(File::LOCK_EX)
    mbox = YAML.load_file(yaml) || {} rescue {}
    mbox[:mtime] = File.mtime(name)

    # read (and unzip) the mailbox
    mails = File.read(name)
    if name.end_with? '.gz'
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

    # process each
    mails.each do |mail|
      # compute id, skip if already processed
      id = hashmail(mail)
      next if mbox[id]
      mail = Mail.read_from_string(mail)

      # parse from address
      begin
	from = Mail::Address.new(mail[:from].value).display_name
      rescue Exception
	from = mail[:from].value
      end

      # determine who should be copied on any responses
      cc = []
      cc = mail[:to].value.split(/,\s*/)  if mail[:to]
      cc += mail[:cc].value.split(/,\s*/) if mail[:cc]

      # remove secretary and anybody on the to field from the cc list
      cc.reject! do |email|
	begin
	  address = Mail::Address.new(email).address
	  return true if address == 'secretary@apache.org'
	  return true if mail.from_addrs.include? address
	rescue Exception
	  true
	end
      end

      # start an entry for this mail
      mbox[id] = {
	from: mail.from_addrs.first,
	name: from,
        time: (mail.date.to_time.gmtime.iso8601 rescue nil),
        cc: cc
      }

      # add in header fields
      mbox[id].merge! headers(mail)

      # add in attachments
      if mail.attachments.length > 0
	attachments = mail.attachments.map do |attach|
	  description = {
            name: attach.filename,
            length: attach.body.to_s.length,
	    mime: attach.mime_type
          }

          description.merge(headers(attach))
	end

	mbox[id][:attachments] = attachments
      end
    end

    # update YAML file
    YAML.dump(mbox, file)
  end
end

puts
