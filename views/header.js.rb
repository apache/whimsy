class Header < React
  def render
    _header.navbar.navbar_fixed_top class: @@item.color do
      _div.navbar_brand @@item.title
      _ul.nav.nav_pills.navbar_right do
        _li.dropdown do
          _a.dropdown_toggle.nav! data_toggle: "dropdown" do
            _ 'navigation'
            _b.caret
          end

          _ul.dropdown_menu do
            _li { _Link text: 'Agenda', href: '' }

            Agenda.index.each do |item|
              _li { _Link text: item.index, href: item.href } if item.index
            end
          end
        end
      end
    end
  end
end
