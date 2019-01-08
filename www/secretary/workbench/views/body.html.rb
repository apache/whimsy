#
# View the email content, without attachments
#

_html do
  _link rel: 'stylesheet', type: 'text/css', 
    href: "../../secmail.css?#{@cssmtime}"

  #
  # Selected headers
  #
  _table do
    _tr do
      _td 'From:'
      _td @message.from
    end

    _tr do
      _td 'To:'
      _td @message.to
    end

    if @message.cc and not @message.cc.empty?
      _tr do
        _td 'Cc:'
        _td @message.cc.join(', ')
      end
    end

    _tr do
      _td 'Subject:'
      _td @message.subject || '(empty)'
    end
  end

  _p

  #
  # Try various ways to display the body
  #
  if @message.html_part
    _div do
      body = @message.html_part.body.to_s

      if body.to_s.encoding == Encoding::BINARY and @message.html_part.charset
        body.force_encoding(@message.html_part.charset) rescue nil
      end

      nodes = _{body.encode('utf-8', invalid: :replace, undef: :replace)}

      fixup_images(nodes)
    end
  elsif @message.text_part
    body = @message.text_part.body.to_s

    if body.to_s.encoding == Encoding::BINARY and @message.text_part.charset
      body.force_encoding(@message.text_part.charset) rescue nil
    end

    _pre.bg_info body.encode('utf-8', invalid: :replace, undef: :replace)
  else # must be a non-multipart message
    body_part = @message.mail.body
    body = body_part.to_s
    mime_type = @message.mail.mime_type

    _.comment! "body.encoding=#{body.encoding} body_part.charset=#{body_part.charset} mime_type=#{mime_type}"

    if body.encoding == Encoding::BINARY and body_part.charset
      body.force_encoding(body_part.charset) rescue nil
    end

    if mime_type == 'text/plain'
      _pre.bg_info body.encode('utf-8', invalid: :replace, undef: :replace)
    elsif mime_type == 'text/html'
      _div do
        nodes = _{body.encode('utf-8', invalid: :replace, undef: :replace)}

        fixup_images(nodes)
      end
    else
      _p "(Cannot handle mime-type #{mime_type})"
    end
  end
end
