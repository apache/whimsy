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

require 'yaml'
require 'time'

require_relative 'mailbox'

database = File.basename(SOURCE)

Dir.chdir File.dirname(File.expand_path(__FILE__))

if ARGV.include? '--fetch1'
  month = Time.now.strftime('%Y%m')
  Dir.mkdir ARCHIVE unless Dir.exist? ARCHIVE
  system "rsync -av --no-motd #{SOURCE}/#{month} #{ARCHIVE}/"
elsif ARGV.include? '--fetch' or not Dir.exist? database
  system "rsync -av --no-motd --delete --exclude='*.yml' #{SOURCE}/ #{ARCHIVE}/"
end

# scan each mailbox for updates
width = 0
Dir[File.join(database, '2*')].sort.each do |name|
  # skip YAML files, update output showing latest file being processed
  next if name.end_with? '.yml'
  next if ARGV.include? '--fetch1'  and not name.include? "/#{month}"
  print "#{name.ljust(width)}\r"
  width = name.length
  
  # test read the YAML file to see if the mbox needs to be parsed
  yaml = File.join(database, File.basename(name)[/\d+/] + '.yml')
  mbox = YAML.load_file(yaml) || {} rescue {}
  next if mbox[:mtime] == File.mtime(name)

  # open the YAML file for real (locking it this time)
  Mailbox.update(name) do |mbox|
    mbox[:mtime] = File.mtime(name)

    # read (and unzip) the mailbox
    messages = Mailbox.new(name)

    # process each
    messages.each do |message|
      # compute id, skip if already processed
      id = Mailbox.hash(message)
      next if mbox[id]
      mail = Mail.read_from_string(message)

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
      mbox[id].merge! Mailbox.headers(mail)

      # add in attachments
      if mail.attachments.length > 0
        attachments = mail.attachments.map do |attach|
          description = {
            name: attach.filename,
            length: attach.body.to_s.length,
            mime: attach.mime_type
          }

          if description[:name].empty? and attach['Content-ID']
            description[:name] = attach['Content-ID'].to_s
          end

          description.merge(Mailbox.headers(attach))
        end

        mbox[id][:attachments] = attachments
      end
    end
  end
end

puts
