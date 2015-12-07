_html do
  _style %{
    td:nth-child(2), th:nth-child(2) {
      padding-right: 7px;
      padding-left: 7px;
    }
  }

  _table do
    _thead do
      _tr do
        _th 'Timestamp'
        _th 'From'
        _th 'Subject'
      end
    end

    @messages.each do |id, description|

      # skip if there are no attachments at all
      next unless description[:attachments]

      _tr_ do
        _td! do
          _a description[:time], href: "#{description[:source]}/#{id}/"
        end 
        _td description[:name]
        _td description['Subject']
      end
    end
  end
end
