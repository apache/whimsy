_html do
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

  if @message.html_part
    _div do
      _{@message.html_part.body.to_s.untaint}
    end
  else
    _pre @message.text_part.body.to_s
  end
end
