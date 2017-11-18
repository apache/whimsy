#
# Encapsulate access to messages
#

require 'digest'
require 'mail'
require 'time'

require_relative 'attachment.rb'

class Message
  attr_reader :headers

  SIG_MIMES = %w(application/pkcs7-signature application/pgp-signature)

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
    name = name[2..-1] if name.start_with? './'

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

  def id
    @headers['Message-ID']
  end

  def date
    mail[:date]
  end

  def from
    mail[:from]
  end

  def to
    mail[:to]
  end

  def cc
    @headers[:cc]
  end

  def cc=(value)
    value=value.split("\n") if String === value
    @headers[:cc]=value
  end

  def bcc
    @headers[:bcc]
  end

  def bcc=(value)
    value=value.split("\n") if String === value
    @headers[:bcc]=value
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

  def self.attachments(headers)
    attachments = headers[:attachments]
    return [] unless attachments
    attachments.
      reject {|attachment| SIG_MIMES.include?(attachment[:mime]) and
        (not attachment[:name] or attachment[:name] !~ /\.pdf\.asc$/)}.
      map {|attachment| attachment[:name]}.
      select {|name| name != 'signature.asc'}
  end

  def attachments
    Message.attachments(@headers)
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
    Dir.mkdir dir, 0755 unless Dir.exist? dir
    File.write File.join(dir, @hash), @email, encoding: Encoding::BINARY
  end

  #
  # write one or more attachments to directory containing an svn checkout
  #
  def write_svn(repos, filename, *attachments)
    # drop all nil and empty values
    attachments = attachments.flatten.reject {|name| name.to_s.empty?}

    # if last argument is a Hash, treat it as name/value pairs
    attachments += attachments.pop.to_a if Hash === attachments.last

    if attachments.flatten.length == 1
      ext = File.extname(attachments.first).downcase.untaint
      find(attachments.first).write_svn(repos, filename + ext)
    else
      # validate filename
      unless filename =~ /\A[a-zA-Z][-.\w]+\z/
        raise IOError.new("invalid filename: #{filename}")
      end

      # create directory, if necessary
      dest = File.join(repos, filename).untaint
      unless File.exist? dest
        Dir.mkdir dest 
        Kernel.system 'svn', 'add', dest
      end

      # write out selected attachment
      attachments.each do |attachment, basename|
        find(attachment).write_svn(repos, filename, basename)
      end

      dest
    end
  end

  #
  # Construct a reply message, and in the process merge the email
  # address from the original message (from, to, cc) with any additional
  # address provided on the call (to, cc, bcc).  Remove any duplicates
  # that may occur not only due to the merge, but also comparing across
  # field types (for example, don't cc an address listed on the to field).
  #
  # Finally, canonicalize (format) the email addresses and ensure that
  # the results aren't marked ask tainted, as the Ruby SMTP library will
  # refuse to send to tainted addresses, and in the secretary mail application
  # the addresses are expected to come from the mail archive and the
  # secretary, both of which can be trusted.
  #
  def reply(fields)
    mail = Mail.new

    # fill in the from address
    mail.from = fields[:from]

    # fill in the reply to headers
    mail.in_reply_to = self.id
    mail.references = self.id

    # fill in the subject from the original email
    if self.subject =~ /^re:\s/i
      mail.subject = self.subject
    elsif self.subject
      mail.subject = 'Re: ' + self.subject
    elsif fields[:subject]
      mail.subject = fields[:subject]
    end

    # fill in the subject from the original email
    mail.body = fields[:body]

    # gather up the to, cc, and bcc addresses
    to = []
    cc = []
    bcc = []

    # process 'to' addresses on method call
    if fields[:to]
      Array(fields[:to]).compact.each do |addr|
        addr = Message.liberal_email_parser(addr) if addr.is_a? String
        next if to.any? {|a| a.address = addr.address}
        to << addr
      end
    end

    # process 'from' addresses from original email
    self.from.addrs.each do |addr|
      next if to.any? {|a| a.address == addr.address}
      if fields[:to]
        next if cc.any? {|a| a.address == addr.address}
        cc << addr
      else
        to << addr
      end
    end

    # process 'to' addresses from original email
    self.to.addrs.each do |addr|
      next if to.any? {|a| a.address == addr.address}
      next if cc.any? {|a| a.address == addr.address}
      cc << addr
    end

    # process 'cc' addresses from original email
    self.cc.each do |addr|
      addr = Message.liberal_email_parser(addr) if addr.is_a? String
      next if to.any? {|a| a.address == addr.address}
      next if cc.any? {|a| a.address == addr.address}
      cc << addr
    end

    # process 'cc' addresses on method call
    if fields[:cc]
      Array(fields[:cc]).compact.each do |addr|
        addr = Message.liberal_email_parser(addr) if addr.is_a? String
        next if to.any? {|a| a.address == addr.address}
        next if cc.any? {|a| a.address == addr.address}
        cc << addr
      end
    end

    # process 'bcc' addresses on method call
    if fields[:bcc]
      Array(fields[:bcc]).compact.each do |addr|
        addr = Message.liberal_email_parser(addr) if addr.is_a? String
        next if to.any? {|a| a.address == addr.address}
        next if cc.any? {|a| a.address == addr.address}
        next if bcc.any? {|a| a.address == addr.address}
        bcc << addr
      end
    end

    # reformat and untaint email addresses
    mail[:to] = to.map {|addr| addr.format.dup.untaint}
    mail[:cc] = cc.map {|addr| addr.format.dup.untaint} unless cc.empty?
    mail[:bcc] = bcc.map {|addr| addr.format.dup.untaint} unless bcc.empty?

    # return the resulting email
    mail
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
      from = liberal_email_parser(mail[:from].value).display_name
    rescue Exception
      from = mail[:from].value.sub(/\s+<.*?>$/)
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
        address = liberal_email_parser(email).address
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

  # see https://github.com/mikel/mail/issues/39
  def self.liberal_email_parser(addr)
    addr = Mail::Address.new(addr)
  rescue Mail::Field::ParseError
    if addr =~ /^"([^"]*)" <(.*)>$/
      addr = Mail::Address.new
      addr.address = $2
      addr.display_name = $1
    elsif addr =~ /^([^"]*) <(.*)>$/
      addr = Mail::Address.new
      addr.address = $2
      addr.display_name = $1
    else
      raise
    end

    return addr
  end
end
