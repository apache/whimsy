class Message
  def initialize(mailbox, hash, headers, email)
    @hash = hash
    @mailbox = mailbox
    @headers = headers
    @email = email
  end

  # find an attachment
  def find(name)
    headers = @headers[:attachments].find do |attach|
      attach[:name] == name
    end

    part = mail.attachments.find do |attach| 
      attach.filename == name or attach['Content-ID'].to_s == name
    end

    if headers
      Attachment.new(self, headers, part)
    end
  end

  def mail
    @mail ||= Mail.new(@email)
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
    mail.html_part
  end

  def attachments
    @headers[:attachments].map {|attachment| attachment[:name]}
  end

  def update_attachment name, values
    attachment = find(name)
    if attachment
      attachment.headers.merge! values
      write
    end
  end

  def replace_attachment name, values
    attachment = find(name)
    if attachment
      index = @headers[:attachments].find_index(attachment.headers)
      @headers[:attachments][index, 1] = Array(values)
      write
    end
  end

  def delete_attachment name
    attachment = find(name)
    if attachment
      @headers[:attachments].delete attachment.headers
      write
    end
  end

  def write
    @mailbox.update do |yaml|
      yaml[@hash] = @headers
    end
  end
end
