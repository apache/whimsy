class Footer < React
  def render
    _footer.navbar.navbar_fixed_bottom class: @@item.color do
      if @@item.prev
        _a.backlink.navbar_brand @@item.prev.title, rel: 'prev', 
         href: @@item.prev.href
      end

      if @@item.next
        _Link.nextlink.navbar_brand text: @@item.next.title, rel: 'next', 
         href: @@item.next.href
      end
    end
  end
end
