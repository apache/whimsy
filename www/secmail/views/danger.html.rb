_html do
  _h1.bg_danger 'Potentially Dangerous Content'

  _table.table.table_bordered do
    _tbody do
      @part.headers.each do |name, value|
        next if name == :mime
        _tr do
          _td name.to_s
          if name == :name
            _td do
              _a value, href: "../#{value}"
            end
          else
            _td value
          end
        end
      end
    end
  end
end
