#
# Header: title on the left, dropdowns on the right
#
# Also keeps the window/tab title in sync with the header title
#
# Finally: make info dropdown status 'sticky'

class Header < Vue
  Header.clock_counter = 0

  def initialize
    @infodropdown = nil
  end

  def render
    _header.navbar.navbar_fixed_top class: @@item.color do
      _div.navbar_brand @@item.title

      if @@item.attach =~ /^7/ and @@item.fulltitle =~ /^Establish .* Project/
        _PodlingNameSearch item: @@item
      end

      _span.clock! "\u231B" if Header.clock_counter > 0

      _ul.nav.nav_pills.navbar_right do

        # pending count
        if Pending.count > 0 or Server.offline
          _li.label.label_danger do
            _span 'OFFLINE: ' if Server.offline

            _Link text: Pending.count, href: 'queue'
          end
        end

        # 'info'/'online' dropdown
        #
        if @@item.attach
          _li.report_info.dropdown class: @infodropdown do
            _a.dropdown_toggle.info! onClick: self.toggleInfo do
              _ 'info'
              _b.caret
            end

            _Info item: @@item, position: 'dropdown-menu'
          end

        elsif @@item.online
          _li.dropdown do
            _a.dropdown_toggle.info! data_toggle: "dropdown" do
              _ 'online'
              _b.caret
            end

            _ul.online.dropdown_menu @@item.online do |id|
              _li do
                _a id, href: "/roster/committer/#{id}"
              end
            end
          end

        else
          _li.dropdown do
            _a.dropdown_toggle.info! data_toggle: "dropdown" do
              _ 'summary'
              _b.caret
            end

            summary = @@item.summary || Agenda.summary

            _table.table_bordered.online.dropdown_menu do
              summary.each do |status|
                text = status.text
                text.sub!(/s$/, '') if status.count == 1
                _tr class: status.color do
                  _td {_Link text: status.count, href: status.href}
                  _td {_Link text: text, href: status.href}
                end
              end
            end
          end
        end

        # 'navigation' dropdown
        #
        _li.dropdown do
          _a.dropdown_toggle.nav! data_toggle: "dropdown" do
            _ 'navigation'
            _b.caret
          end

          _ul.dropdown_menu do
            _li { _Link.agenda! text: 'Agenda', href: '.' }

            Agenda.index.each do |item|
              _li { _Link text: item.index, href: item.href } if item.index
            end

            _li.divider

            _li { _Link text: 'Search', href: 'search' }
            _li { _Link text: 'Comments', href: 'comments' }

            shepherd = Agenda.shepherd
            if shepherd
              _li do
                _Link.shepherd! text: 'Shepherd', href: "shepherd/#{shepherd}"
              end
            end

            _li { _Link.queue! text: 'Queue', href: 'queue' }

            _li.divider

            _li { _Link.backchannel! text: 'Backchannel', href: 'backchannel' }

            _li { _Link.help! text: 'Help', href: 'help' }
          end
        end

      end
    end
  end

  # toggle info dropdown
  def toggleInfo()
    @infodropdown = (@infodropdown ? nil : 'open')
  end
end
