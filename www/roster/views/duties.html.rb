#
# Organization Chart
# NOTE: this view of the data is Member-private
PVTCLASS = 'text-warning'
_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"

  _body? do
    _whimsy_body(
      title: @role['info']['role'],
      breadcrumbs: {
        roster: '.',
        orgchart: 'orgchart/' # This is a sub-page of orgchart
      }
    ) do
      id = @role['info']['id'] || @role['info']['chair']
      _whimsy_panel_table(
        title: "#{@role['info']['role']} - #{ASF::Person.find(id).public_name}",
        helpblock: -> {
          _ 'Note that this detail page includes  '
          _span.glyphicon.glyphicon_lock :aria_hidden, class: 'text-primary', aria_label: 'ASF Members Private'
          _span ' Member private data.', class: PVTCLASS
        }
      ) do
        # ********************************************************************
        # *                             Summary                              *
        # ********************************************************************
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
#                      TODO allow for multiple holders?
                      _a value, href: "committer/#{value}"
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
                _td class: pvt do
                  _(@desc[key]) if @desc.key?(key)
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
          _ul.list_group do
            _li.list_group_item.active do
              _h4 'This Officer Oversees'
            end
            _li.list_unstyled do
              _ul style: 'margin-top: 15px; margin-bottom: 15px;' do
                @oversees.each do |name, duties|
                  _li do
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
        _ul.list_group do
          @role.each do |title, text|
            next if title == 'info' or title == 'mtime'
            _li.list_group_item.active do
              (title =~ /private/i) ? _h4.text_capitalize.text_warning(title) : _h4.text_capitalize(title)
            end
            _li.list_group_item do
              _markdown text
            end
          end
        end

        # ********************************************************************
        # *                           Source Code                            *
        # ********************************************************************
        _ul.list_group do
          _li.list_group_item.active do
            _h4.text_warning('See This Source File')
          end
          _li.list_group_item do
            txtnam = File.basename(env['REQUEST_URI'])
            _a "foundation/officers/personnel-duties/#{txtnam}.txt", href: ASF::SVN.svnpath!('personnel-duties', "#{txtnam}.txt")
          end
        end

      end
    end
  end
end
