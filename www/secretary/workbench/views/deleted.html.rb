_html do
  _h1.bg_danger "Deleted messages for #{@mbox}"
  _a 'Workbench', href: '..'
  if @prv
    _a 'Previous', href: "../#{@prv}/deleted"
  end
  if @nxt
    _a 'Next', href: "../#{@nxt}/deleted"
  end
  _table.table do
    _thead do
      _tr do
        _th 'Timestamp'
        _th 'From'
        _th 'Subject'
      end
    end
    _tbody do
      @messages.each do |msg|
        time = Time.parse(msg[:time]).to_s
        _tr do
          _td do
            _a time, href: '../%s' % msg[:href], title: time
          end
          _td msg[:from]
          _td msg[:subject]
        end
      end
    end
  end
  _hr
end
