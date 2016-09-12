#
# View the email content, without attachments
#

_html do
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
        body.force_encoding(@message.html_part.charset)
      end

      nodes = _{body.encode('utf-8', invalid: :replace, undef: :replace)}

      fixup_images(nodes)
    end
  elsif @message.text_part
    body = @message.text_part.body.to_s

    if body.to_s.encoding == Encoding::BINARY and @message.text_part.charset
      body.force_encoding(@message.text_part.charset)
    end

    _pre body.encode('utf-8', invalid: :replace, undef: :replace)
  end
end
