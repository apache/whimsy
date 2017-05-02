#
# Organization Chart
# NOTE: this view of the data is Member-private
PVTCLASS = 'text-warning'
_html do
  _title @role['info']['role']
  _base href: '..'
  _link rel: 'stylesheet', href: 'stylesheets/app.css'

  _banner breadcrumbs: {
    roster: '.',
    orgchart: 'orgchart/'
  }

  # ********************************************************************
  # *                             Summary                              *
  # ********************************************************************

   id = @role['info']['id'] || @role['info']['chair']
  _h1_ "#{@role['info']['role']} - #{ASF::Person.find(id).public_name}"

  _h2_ do
    _ 'Quick Info'
    _small do 
      _ ' - includes '
      _span 'Member private data', class: PVTCLASS
    end
  end

  _table.table do
    _tbody do
      @role['info'].each do |key, value|
        next if key == 'role'
        next unless value
        (key =~ /private/i) ? (pvt = PVTCLASS) : (pvt = '')
        _tr_ do
          _td key, class: pvt

          if %w(id chair).include? key
            _td class: pvt do
              if value == 'tbd'
                _span value
              else
                _a value, href: "roster/#{value}"
              end
            end
          elsif %w(reports-to).include? key
            _td! class: pvt do
              value.split(/[, ]+/).each_with_index do |role, index|
                _span ', ' if index > 0
                if role == 'members'
                  _a role, href: "roster/members"
                else
                  _a role, href: "orgchart/#{role}"
                end
              end
            end
          elsif %w(email).include? key
            _td class: pvt do
              _a value, href: "mailto:#{value}"
            end
          elsif %w(private-list).include? key
            _td class: pvt do
              if value == 'board-private@apache.org'
                _a value, href: "mailto:#{value}"
              else
                _a value, href: "https://lists.apache.org/list.html?#{value}"
              end
            end
          elsif %w(roster resolution).include? key
            _td class: pvt do
              _a value, href: value
            end
          else
            _td value, class: pvt 
          end
        end
      end
    end
  end

  # ********************************************************************
  # *                             Oversees                             *
  # ********************************************************************

  unless @oversees.empty?
    @oversees = @oversees.sort_by {|name, duties| duties['info']['role']}
    _h2 'Oversees'
    _table.table do
      _tbody do
        @oversees.each do |name, duties|
          _tr do
            _td do
              _a duties['info']['role'], href: "orgchart/#{name}"
            end
          end
        end
      end
    end
  end

  # ********************************************************************
  # *                             Details                              *
  # ********************************************************************

  @role.each do |title, text|
    next if title == 'info' or title == 'mtime'
    (title =~ /private/i) ? _h2.text_capitalize.text_warning(title) : _h2.text_capitalize(title)
    _markdown text
  end
end
