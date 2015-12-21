class Attachment
  def initialize(headers, part)
    @headers = headers
    @part = part
  end

  def content_type
    @part.content_type
  end

  def body
    @part.body
  end
end
