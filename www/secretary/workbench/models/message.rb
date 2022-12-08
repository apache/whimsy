#
# Encapsulate access to messages
#
# N.B. this module is referenced by the deliver script, so needs to be quick to load

require 'digest'
require 'mail'
require 'time'

require_relative 'attachment'

class Message
  attr_reader :headers

  SIG_MIMES = %w(application/pkcs7-signature application/pgp-signature)

  # The name used to represent the raw message as an attachment
  RAWMESSAGE_ATTACHMENT_NAME = 'rawmessage.txt'

  #
  # create a new message
  #
  def initialize(mailbox, hash, headers, raw)
    @hash = hash
    @mailbox = mailbox
    @headers = headers
    @raw = raw
  end

  #
  # find an attachment
  #
  def find(name)
    name = name[1..-2] if name =~ /^<.*>$/ # drop enclosing <> if present
    name = name[2..-1] if name.start_with? './'
    name = name.dup.force_encoding('utf-8')

    headers = @headers[:attachments].find do |attach|
      attach[:name] == name or attach['Content-ID'].to_s == "<#{name}>"
    end

    part = mail.attachments.find do |attach|
      attach.filename == name or attach['Content-ID'].to_s == "<#{name}>"
    end

    if part.nil? and name == RAWMESSAGE_ATTACHMENT_NAME
      part = self
    end

    if headers
      Attachment.new(self, headers, part)
    end
  end

  #
  # accessors
  #

  def mail
    @mail ||= Mail.new(@raw.gsub(LF_ONLY, CRLF))
  end

  # Allows the entire message to be treated as an attachment
  # used with RAWMESSAGE_ATTACHMENT_NAME
  def body
    @raw
  end

  def raw
    @raw
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
    value = value.split("\n") if value.is_a? String
    @headers[:cc] = value
  end

  def bcc
    @headers[:bcc]
  end

  def bcc=(value)
    value = value.split("\n") if value.is_a? String
    @headers[:bcc] = value
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
        (not attachment[:name] or attachment[:name] !~ /\.pdf\.(asc|sig)$/)}.
      map {|attachment| attachment[:name]}.
      reject {|name| name == 'signature.asc'}
  end

  def attachments
    Message.attachments(@headers)
  end

  #
  # attachment operations: update, replace, delete
  #

  def update_attachment(name, values)
    attachment = find(name)
    if attachment
      attachment.headers.merge! values
      write_headers
    end
  end

  def replace_attachment(name, values)
    attachment = find(name)
    if attachment
      index = @headers[:attachments].find_index(attachment.headers)
      @headers[:attachments][index, 1] = Array(values)
      write_headers
    end
  end

  def delete_attachment(name)
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
    Dir.mkdir dir, 0o755 unless Dir.exist? dir
    File.write File.join(dir, @hash), @raw, encoding: Encoding::BINARY
  end

  #
  # write one or more attachments to directory containing an svn checkout
  #
  def write_svn(repos, filename, *attachments)
    # drop all nil and empty values
    attachments = attachments.flatten.reject {|name| name.to_s.empty?}

    # if last argument is a Hash, treat it as name/value pairs
    attachments += attachments.pop.to_a if attachments.last.is_a? Hash

    if attachments.flatten.length == 1
      ext = File.extname(attachments.first).downcase
      find(attachments.first).write_svn(repos, filename + ext)
    else
      # validate filename
      unless filename =~ /\A[a-zA-Z][-.\w]+\z/
        raise IOError.new("invalid filename: #{filename}")
      end

      # create directory, if necessary
      dest = File.join(repos, filename)
      unless File.exist? dest
        Kernel.system 'svn', 'mkdir', dest
      end

      # write out selected attachment
      attachments.each do |attachment, basename|
        find(attachment).write_svn(repos, filename, basename)
      end

      dest
    end
  end

  #
  # write one or more attachments
  # returns list as follows:
  # [[name, temp file name, content-type]]
  def write_att(tmpdir, *attachments)
    files = []

    # drop all nil and empty values
    attachments = attachments.flatten.reject {|name| name.to_s.empty?}

    # write out any remaining attachments
    attachments.each do |name|
      att = find(name)
      path = File.join(tmpdir, name)
      att.write_path(path)
      files << [name, path, att.content_type]
    end

    files
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

    # process 'bcc' addresses on method call
    # Do this first so can suppress such addresses in To: and Cc: fields
    if fields[:bcc]
      Array(fields[:bcc]).compact.each do |addr|
        addr = Message.liberal_email_parser(addr) if addr.is_a? String
        next if bcc.any? {|a| a.address == addr.address}
        bcc << addr
      end
    end

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
        next if bcc.any? {|a| a.address == addr.address} # skip if already in Bcc
        cc << addr
      else
        to << addr
      end
    end

    # process 'to' addresses from original email
    if self.to
      self.to.addrs.each do |addr|
        next if to.any? {|a| a.address == addr.address}
        next if cc.any? {|a| a.address == addr.address}
        next if bcc.any? {|a| a.address == addr.address} # skip if already in Bcc
        cc << addr
      end
    end

    # process 'cc' addresses from original email
    if self.cc
      self.cc.each do |addr|
        addr = Message.liberal_email_parser(addr) if addr.is_a? String
        next if to.any? {|a| a.address == addr.address}
        next if cc.any? {|a| a.address == addr.address}
        next if bcc.any? {|a| a.address == addr.address} # skip if already in Bcc
        cc << addr
      end
    end

    # process 'cc' addresses on method call
    if fields[:cc]
      Array(fields[:cc]).compact.each do |addr|
        addr = Message.liberal_email_parser(addr) if addr.is_a? String
        next if to.any? {|a| a.address == addr.address}
        next if cc.any? {|a| a.address == addr.address}
        next if bcc.any? {|a| a.address == addr.address} # skip if already in Bcc
        cc << addr
      end
    end

    # reformat email addresses
    mail[:to] = to.map(&:format)
    mail[:cc] = cc.map(&:format) unless cc.empty?
    mail[:bcc] = bcc.map(&:format) unless bcc.empty?

    # return the resulting email
    mail
  end

  # get the message ID
  def self.getmid(message)
    # only search headers for MID
    hdrs = message[/\A(.*?)\r?\n\r?\n/m, 1] || ''
    mid = hdrs[/^Message-ID:.*/i]
    if mid =~ /^Message-ID:\s*$/i # no mid on the first line
      # capture the next line and join them together
      # line may also start with tab; we don't use \s as this also matches EOL
      # Rescue is in case we don't match properly - we want to return nil in that case
      mid = hdrs[/^Message-ID:.*\r?\n[ \t].*/i].sub(/\r?\n/,'') rescue nil
    end
    mid
  end

  #
  # What to use as a hash for mail
  #
  def self.hash(message)
    Digest::SHA1.hexdigest(getmid(message) || message)[0..9]
  end

  # Matches LF, but not CRLF
  LF_ONLY = Regexp.new("(?<!\r)\n")
  CRLF = "\r\n"

  #
  # parse a message, returning headers
  #
  def self.parse(message)

    # parse cleaned up message (need to fix every line, not just headers)
    mail = Mail.read_from_string(message.gsub(LF_ONLY, CRLF))

    # parse from address (if it exists)
    from_value = mail[:from].value rescue ''
    begin
      from = liberal_email_parser(from_value).display_name
    rescue Exception
      from = from_value.sub(/\s+<.*?>$/, '')
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
    # we also want to treat CLA requests as attachments
    elsif headers['Subject']&.include?('CLA') &&
         !headers['Subject'].include?('ICLA') &&
         !headers['Subject'].include?('iCLA')
      headers[:attachments] = [
        {name: RAWMESSAGE_ATTACHMENT_NAME,
          length: message.size,
          mime: 'text/plain'}
      ]
    end

    headers
  end

  # see https://github.com/mikel/mail/issues/39
  def self.liberal_email_parser(addr)
    addr = Mail::Address.new(addr)
  rescue Mail::Field::ParseError
    if addr =~ /^"([^"]*)" <(.*)>$/ or
       addr =~ /^([^"]*) <(.*)>$/
      addr = Mail::Address.new
      addr.address = $2
      addr.display_name = $1
    else
      raise
    end

    return addr
  end
end
