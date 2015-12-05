_html do
  _table do
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
