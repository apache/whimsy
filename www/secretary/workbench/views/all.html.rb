_html do
  _h1 'All messages'
  _table.table do
    _thead do
      _tr do
        _th 'Status'
        _th 'Timestamp'
        _th 'From'
        _th 'Subject'
      end
    end
    _tbody do
      @messages.each do |msg|
        time = Time.parse(msg[:time]).to_s
        _tr do
          _td msg[:status].to_s
          _td do
            _a time, href: "../%s" % msg[:href], title: time
          end
          _td msg[:from]
          _td msg[:subject]
        end
      end
    end
  end
  _hr
end
