class Footer < React
  def initialize
    @buttons = nil
  end

  def componentWillMount()
    self.componentWillReceiveProps(self.props)
  end

  def componentWillReceiveProps(newprops)
    @buttons = newprops.item.buttons
  end

  def render
    _footer.navbar.navbar_fixed_bottom class: @@item.color do
      if @@item.prev
        _a.backlink.navbar_brand @@item.prev.title, rel: 'prev', 
         href: @@item.prev.href
      end

      if @buttons
        @buttons.each do |button|
          React.createElement(button, item: @@item) if button
        end
      end

      if @@item.next
        _Link.nextlink.navbar_brand text: @@item.next.title, rel: 'next', 
         href: @@item.next.href
      end
    end
  end
end
