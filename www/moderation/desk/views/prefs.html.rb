require_relative '../defines'

# Update the project list
_html do
  _title 'ASF Moderation Helper - select preferences'
  _link rel: 'stylesheet', type: 'text/css', href: "secmail.css?#{@cssmtime}"

  _header_ do
    _h1.bg_success do
      _a 'ASF Moderation Helper', href: '.', target: '_top'
      _ ' - select preferences'
    end
  end

  _h1 "Set preferences for #{@id}"

  _form method: 'post', action: 'actions/setprefs' do
    _table.table do
      _tr do
        _th 'Selected'
        _th 'Project'
      end
      if @info[:member]
        _tr do
          _td do
            _input type: 'checkbox', name: ALLDOMAINS, checked: @domains.include?(ALLDOMAINS)            
          end
          _td '*** All domains ***'
        end
      end
      @info[:project_owners].each do |up|
        up += '.apache.org' # TODO improve this
        _tr do
          _td do
            _input type: 'checkbox', name: up, checked: @domains.include?(up)
          end
          _td up
        end
      end
    end
    _input.btn.btn_primary value: 'Update', type: 'submit', ref: 'update'    
  end
  _p do
    _ 'Return to '
    _a 'ASF Moderation Helper', href: '.', target: '_top'
  end
end
