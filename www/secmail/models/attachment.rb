class Attachment
  IMAGE_TYPES = %w(.gif, .jpg, .jpeg, .png)
  attr_reader :headers

  def initialize(message, headers, part)
    @message = message
    @headers = headers
    @part = part
  end

  def content_type
    headers[:mime] || @part.content_type
  end

  def body
    headers[:content] || @part.body
  end

  def safe_name
    name = @part.filename
    name.gsub! /^\W/, ''
    name.gsub! /[^\w.]/, '_'
    name.untaint
  end

  def as_pdf
    file = Tempfile.new([safe_name, '.pdf'], encoding: Encoding::BINARY)
    file.write(body)
    file.rewind

    return file if content_type.end_with? '/pdf'
    return file if @part.filename.end_with? '.pdf'

    ext = File.extname(@part.filename).downcase

    if IMAGE_TYPES.include? ext or content_type.start_with? 'image/'
      pdf = Tempfile.new([safe_name, '.pdf'], encoding: Encoding::BINARY)
      system 'convert', file.path, pdf.path
      file.unlink
      return pdf
    end

    return file
  end
end
