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
      _td @message[:from]
    end

    _tr do
      _td 'To:'
      _td @message[:to]
    end

    if @message[:cc]
      _tr do
        _td 'Cc:'
        _td @message[:cc]
      end
    end

    _tr do
      _td 'Subject:'
      _td @message.subject
    end
  end

  _p
  _hr
  _p

  #
  # Try various ways to display the body
  #
  success = false
  if @message.html_part and @message.html_part.body.to_s.valid_encoding?
    _div do
      begin
        _{@message.html_part.body.to_s.untaint}
        success = true
      rescue
      end
    end
  end

  if not success and @message.text_part.body
    begin
      _pre @message.text_part.body.to_s.encode('utf-8')
    rescue
      body = @message.text_part.body.to_s.force_encoding('windows-1252')
      _pre body.encode('utf-8', invalid: :replace, undef: :replace)
    end
  end
end
