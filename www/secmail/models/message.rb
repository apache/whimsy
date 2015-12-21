class Message
  def initialize(headers, email)
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

    if part
      Attachment.new(headers, part)
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
end
