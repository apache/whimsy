#
# Encapsulate access to mailboxes
#

require 'digest'
require 'zlib'
require 'zip'
require 'stringio'
require 'mail'
require 'yaml'

require_relative '../config.rb'

require_relative 'message.rb'
require_relative 'attachment.rb'

class Mailbox
  #
  # fetch a/some/all mailboxes
  #
  def self.fetch(mailboxes=nil)
    options = %w(-av --no-motd)

    if mailboxes == nil
      options += %w(--delete --exclude=*.yml)
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
    name = File.basename(name, '.yml') if name.end_with? '.yml'

    if name =~ /^\d+$/
      @filename = Dir["#{ARCHIVE}/#{name}", "#{ARCHIVE}/#{name}.gz"].first.
        untaint
    else
      @filename = name
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
    headers = YAML.load_file(yaml_file) rescue {}
    email = messages.find {|message| Mailbox.hash(message) == hash}
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
    source = File.basename(@filename, '.gz').untaint
    "#{ARCHIVE}/#{source}.yml"
  end

  #
  # return headers
  #
  def headers
    source = File.basename(@filename, '.gz').untaint
    messages = YAML.load_file(yaml_file) rescue {}
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

  #
  # parse a mailbox, updating YAML
  #
  def parse
    mbox = YAML.load_file(yaml_file) || {} rescue {}
    return if mbox[:mtime] == File.mtime(@filename)

    # open the YAML file for real (locking it this time)
    self.update do |mbox|
      mbox[:mtime] = File.mtime(@filename)

      # process each message in the mailbox
      self.each do |message|
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
        begin
          cc = []
          cc = mail[:to].to_s.split(/,\s*/)  if mail[:to]
          cc += mail[:cc].to_s.split(/,\s*/) if mail[:cc]
        rescue
          cc = []
          cc = mail[:to].value.split(/,\s*/)  if mail[:to]
          cc += mail[:cc].value.split(/,\s*/) if mail[:cc]
        end

        # remove secretary and anybody on the to field from the cc list
        cc.reject! do |email|
          begin
            address = Mail::Address.new(email).address
            next true if address == 'secretary@apache.org'
            next true if mail.from_addrs.include? address
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
            # replace generic octet-stream with a more specific one
            mime = attach.mime_type
            if mime == 'application/octet-stream'
              filename = attach.filename.downcase
              mime = 'application/pdf' if filename.end_with? '.pdf'
              mime = 'application/png' if filename.end_with? '.png'
              mime = 'application/gif' if filename.end_with? '.gif'
              mime = 'application/jpeg' if filename.end_with? '.jpg'
              mime = 'application/jpeg' if filename.end_with? '.jpeg'
            end

            description = {
              name: attach.filename,
              length: attach.body.to_s.length,
              mime: mime
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
end
