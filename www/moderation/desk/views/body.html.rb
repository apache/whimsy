#
# View the email content
#

_html do
  _link rel: 'stylesheet', type: 'text/css', 
    href: "../../secmail.css?#{@cssmtime}"

  #
  # Selected headers
  #
  _table do
    if @headers[:list]
      _tr do
        _td 'Mailing-list:'
        _td @headers[:list] + '@' + @headers[:domain]
      end
    end
    _tr do
      _td 'From:'
      _td @message.from
    end

    _tr do
      _td 'Return-Path: '
      _td @message.return_path
    end

    _tr do
      _td 'Reply-To: '
      _td @message.reply_to
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
    @attachments.each do |att|
      attname = att[:name]
      attid = att['Content-ID']
      if attname =~ /\.(pdf|txt|jpeg|jpg|gif|png)$/i
        link = "#{attid}"
      else
        link = "_danger_/#{attid}"
      end
      _tr do
        _td 'Attachment: '
        _td do
          _a attname, href: link, target: 'content'
        end
      end
    end
  end

  _p

  #
  # Try various ways to display the body
  #
  if @message.html_part
    _div do # N.B. this is needed for HTML output
      container = @message.html_part
      body = container.body.to_s

      # Debug
      _.comment! "html_part: body.encoding=#{body.encoding} container.charset=#{container.charset}"
    
      if body.encoding == Encoding::BINARY and container.charset
        body.force_encoding(container.charset) rescue nil
      end

      nodes = _{body.encode('utf-8', invalid: :replace, :undef => :replace)}

      fixup_images(nodes)
    end
  elsif @message.text_part
    container = @message.text_part
    body = container.body.to_s

    # Debug
    _.comment! "text_part: body.encoding=#{body.encoding} container.charset=#{container.charset}"
  
    if body.encoding == Encoding::BINARY and container.charset
      body.force_encoding(container.charset) rescue nil
    end

    _pre.bg_info body.encode('utf-8', invalid: :replace, :undef => :replace)
  else # must be a non-multi part mail
    container = @message.mail
    body = container.body.to_s
    
    # Debug
    _.comment! "body.encoding=#{body.encoding} container.charset=#{container.charset} container.mime_type=#{container.mime_type}"
    
    if body.encoding == Encoding::BINARY and container.charset
      body.force_encoding(container.charset) rescue nil
    end
    
    if container.mime_type == 'text/plain'

      _pre.bg_info body.encode('utf-8', invalid: :replace, :undef => :replace)

    elsif container.mime_type == 'text/html'

      _div do # N.B. this is needed for HTML output
        nodes = _{body.encode('utf-8', invalid: :replace, :undef => :replace)}
    
        fixup_images(nodes)
      end

    else

      _p "(Cannot handle mime-type #{mime_type})"

    end
  end
end
