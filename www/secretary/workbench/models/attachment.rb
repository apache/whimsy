require 'open3'

class Attachment
  IMAGE_TYPES = %w(.gif .jpg .jpeg .png)
  attr_reader :headers

  def initialize(message, headers, part)
    @message = message
    @headers = headers
    @part = part
  end

  def name
    headers[:name] || @part.filename
  end

  def content_type
    type = headers[:mime] || @part.content_type

    if type == 'application/octet-stream' or type == 'text/plain'
      type = 'text/plain' if name.end_with? '.sig'
      type = 'text/plain' if name.end_with? '.asc'
      type = 'application/pdf' if name.end_with? '.pdf'
      type = 'image/gif' if name.end_with? '.gif'
      type = 'image/jpeg' if name.end_with? '.jpg'
      type = 'image/jpeg' if name.end_with? '.jpeg'
      type = 'image/png' if name.end_with? '.png'
    end

    type = "image/#{$1}" if type =~ /^application\/(jpeg|gif|png)$/

    type
  end

  def body
    headers[:content] || @part.body
  end

  def safe_name
    name = self.name.dup
    name.gsub! %r{[^\w.]}, '_'
    name
  end

  # writes the attachment to the specified pathname, which must not exist
  def write_path(path)
    File.open(path, File::WRONLY|File::CREAT|File::EXCL, encoding: Encoding::BINARY) do |file|
      file.write body
    end
  end

  # Returns the attachment as an open temporary file
  # Warning: if the reference count goes to 0, the file may be deleted
  # so calling code must retain the reference until done.
  def as_file
    file = Tempfile.new([safe_name, '.pdf'], encoding: Encoding::BINARY)
    file.write(body)
    file.rewind
    file
  end

  def as_pdf
    ext = File.extname(name).downcase
    ext = '.pdf' if content_type.end_with? '/pdf'

    file = Tempfile.new([safe_name, ext], encoding: Encoding::BINARY)
    file.write(body)
    file.rewind

    return file if ext == '.pdf'

    if IMAGE_TYPES.include? ext or content_type.start_with? 'image/'
      pdf = Tempfile.new([safe_name, '.pdf'], encoding: Encoding::BINARY)
      img2pdf = File.expand_path('../img2pdf', __dir__)
      _stdout, stderr, status = Open3.capture3 img2pdf, '--output', pdf.path,
        file.path

      # img2pdf will refuse if there is an alpha channel.  If that happens
      # use imagemagick to remove the alpha channel and try again.
      unless status.exitstatus == 0
        if stderr.include? 'remove the alpha channel'
          tmppng = Tempfile.new([safe_name, '.png'], encoding: Encoding::BINARY)
          system 'convert', file.path, '-background', 'white', '-alpha',
            'remove', '-alpha', 'off', tmppng.path

          if File.size? tmppng.path
            _stdout, stderr, _status = Open3.capture3 img2pdf, '--output',
              pdf.path, tmppng.path
          end

          tmppng.unlink
        end
      end

      file.unlink

      unless File.size? pdf.path
        STDERR.print stderr unless stderr.empty?
        raise "Failed to convert #{self.name} to PDF"
      end

      return pdf
    end

    return file
  end

  # write a file out to svn
  def write_svn(repos, file, path=nil)
    filename = File.join(repos, file)
    filename = File.join(filename, path || safe_name) if Dir.exist? filename

    raise Errno::EEXIST.new(file) if File.exist? filename
    File.write filename, body, encoding: Encoding::BINARY

    system 'svn', 'add', filename
    system 'svn', 'propset', 'svn:mime-type', content_type, filename

    filename
  end
end
