#
# Encapsulate access to messages
#

require 'digest'
require 'mail'
require 'time'

require_relative 'attachment.rb'

class Message
  attr_reader :headers

  #
  # create a new message
  #
  def initialize(mailbox, hash, headers, email)
    @hash = hash
    @mailbox = mailbox
    @headers = headers
    @email = email
  end

  #
  # find an attachment
  #
  def find(name)
    name = name[1...-1] if name =~ /<.*>/

    headers = @headers[:attachments].find do |attach|
      attach[:name] == name or attach['Content-ID'].to_s == '<' + name + '>'
    end

    part = mail.attachments.find do |attach| 
      attach.filename == name or attach['Content-ID'].to_s == '<' + name + '>'
    end

    if headers
      Attachment.new(self, headers, part)
    end
  end

  #
  # accessors
  #

  def mail
    @mail ||= Mail.new(@email)
  end

  def raw
    @email
  end

  def from
    mail[:from]
  end

  def to
    mail[:to]
  end

  def cc
    mail[:cc]
  end

  def subject
    mail.subject
  end

  def html_part
    mail.html_part
  end

  def text_part
    mail.text_part
  end

  def attachments
    @headers[:attachments].map {|attachment| attachment[:name]}
  end

  #
  # attachment operations: update, replace, delete
  #

  def update_attachment name, values
    attachment = find(name)
    if attachment
      attachment.headers.merge! values
      write_headers
    end
  end

  def replace_attachment name, values
    attachment = find(name)
    if attachment
      index = @headers[:attachments].find_index(attachment.headers)
      @headers[:attachments][index, 1] = Array(values)
      write_headers
    end
  end

  def delete_attachment name
    attachment = find(name)
    if attachment
      @headers[:attachments].delete attachment.headers
      @headers[:status] = :deleted if @headers[:attachments].empty?
      write_headers
    end
  end

  #
  # write updated headers to disk
  #
  def write_headers
    @mailbox.update do |yaml|
      yaml[@hash] = @headers
    end
  end

  #
  # write email to disk
  #
  def write_email
    dir = @mailbox.dir
    Dir.mkdir dir unless Dir.exist? dir
    File.write File.join(dir, @hash), @email, encoding: Encoding::BINARY
  end

  #
  # write one or more attachments to directory containing an svn checkout
  #
  def write_svn(repos, filename, *attachments)
    attachments = attachments.flatten.compact

    if attachments.length == 1
      ext = File.extname(attachments.first).untaint
      find(attachments.first).write_svn(repos, filename + ext)
    else
      # validate filename
      unless filename =~ /\A[a-zA-Z][-.\w]+\Z/
	      raise IOError.new("invalid filename: #{filename}")
      end

      # ensure directory doesn't exist
      dest = File.join(repos, filename).untaint
      raise Errno::EEXIST.new(filename) if File.exist? dest

      # create directory
      Dir.mkdir dest

      # write out selected attachment
      attachments.each do |attachment|
        find(attachment).write_svn(repos, filename)
      end

      Kernel.system 'svn', 'add', dest
      dest
    end
  end

  #
  # What to use as a hash for mail
  #
  def self.hash(message)
    Digest::SHA1.hexdigest(message[/^Message-ID:.*/i] || message)[0..9]
  end

  #
  # parse a message, returning headers
  #
  def self.parse(message)
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
    headers = {
      from: mail.from_addrs.first,
      name: from,
      time: (mail.date.to_time.gmtime.iso8601 rescue nil),
      cc: cc
    }

    # add in header fields
    headers.merge! Mailbox.headers(mail)

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

      headers[:attachments] = attachments
    end

    headers
  end
end
