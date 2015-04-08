#
# Layout footer consisting of a previous link, any number of buttons,
# followed by a next link.
#

class Footer < React
  def render
    _footer.navbar.navbar_fixed_bottom class: @@item.color do
      if @@item.prev
        _a.backlink.navbar_brand @@item.prev.title, rel: 'prev', 
         href: @@item.prev.href
      end

      if @@buttons
        _span do
          @@buttons.each do |button|
            if button.text
              React.createElement('button', button.attrs, button.text)
            elsif button.type
              React.createElement(button.type, button.attrs)
            end
          end
        end
      end

      if @@item.next
        _Link.nextlink.navbar_brand text: @@item.next.title, rel: 'next', 
         href: @@item.next.href
      end
    end
  end
end
