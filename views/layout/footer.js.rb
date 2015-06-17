#
# Layout footer consisting of a previous link, any number of buttons,
# followed by a next link.
#

class Footer < React
  def render
    _footer.navbar.navbar_fixed_bottom class: @@item.color do

      #
      # Previous link
      #
      link = @@item.prev
      prefix = ''

      if @@options.traversal == :queue
        prefix = 'queue/'
        while link and not link.ready_for_review(Server.initials)
          link = link.prev
        end
        link ||= {href: '../queue', title: 'Queue'}
      elsif @@options.traversal == :shepherd
        prefix = 'shepherd/queue/'
        while link and link.shepherd != @@item.shepherd
          link = link.prev
        end
        link ||= {href: "../#{@@item.shepherd}", title: 'Shepherd'}
      elsif @@options.traversal == :flagged
        prefix = 'flagged/'
        while link and not link.flagged
          link = link.prev
        end
        link ||= {href: "", title: 'Flagged'}
      end

      if link
        _Link.backlink.navbar_brand text: link.title, rel: 'prev', 
         href: "#{prefix}#{link.href}"
      elsif @@item.prev or @@item.next
        # without this, Chrome will sometimes make the footer too tall
        _a.navbar_brand
      end

      #
      # Buttons
      #
      _span do
        if @@buttons
          @@buttons.each do |button|
            if button.text
              React.createElement('button', button.attrs, button.text)
            elsif button.type
              React.createElement(button.type, button.attrs)
            end
          end
        end
      end

      #
      # Next link
      #
      link = @@item.next

      if @@options.traversal == :queue
        while link and not link.ready_for_review(Server.initials)
          link = link.next
        end
        link ||= {href: '../queue', title: 'Queue'}
      elsif @@options.traversal == :shepherd
        while link and link.shepherd != @@item.shepherd
          link = link.next
        end
        link ||= {href: "../#{@@item.shepherd}", title: 'Shepherd'}
      elsif @@options.traversal == :flagged
        prefix = 'flagged/'
        while link and not link.flagged
          link = link.next
        end
        link ||= {href: "", title: 'Flagged'}
      end

      if link
        _Link.nextlink.navbar_brand text: link.title, rel: 'next', 
         href: "#{prefix}#{link.href}"
      elsif @@item.prev or @@item.next
        # keep Chrome happy
        _a.nextarea.navbar_brand
      end
    end
  end
end
