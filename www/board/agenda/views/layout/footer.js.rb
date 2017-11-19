#
# Layout footer consisting of a previous link, any number of buttons,
# followed by a next link.
#
# Overrides previous and next links when traversal is queue, shepherd, or
# Flagged.  Injects the flagged items into the flow once the meeting starts
# (last additional officer <-> first flagged &&
#  last flagged <-> first Special order)
#

class Footer < Vue
  def render
    _footer.navbar.navbar_fixed_bottom class: @@item.color do

      #
      # Previous link
      #
      link = @@item.prev
      prefix = ''

      if @@options.traversal == :queue
        prefix = 'queue/'
        while link and not link.ready_for_review(User.initials)
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

        unless link
          if Minutes.started
            link = Agenda.index.find {|item| item.attach == 'A'}.prev
            prefix = ''
          end

          link ||= {href: "../flagged", title: 'Flagged'}
        end
      elsif 
        Minutes.started and @@item.attach =~ /\d/ and
        link and link.attach =~ /^[A-Z]/
      then
        Agenda.index.each do |item| 
          if item.flagged and item.attach =~ /^[A-Z]/
            prefix = 'flagged/'
            link = item 
          end
        end
      end

      if link
        _Link.backlink.navbar_brand text: link.title, rel: 'prev', 
         href: "#{prefix}#{link.href}", class: link.color
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
              props = {attrs: button.attrs}
              if button.attrs.class
                props.class = button.attrs.class.split(' ')
                delete button.attrs.class
              end

              Vue.createElement('button', props, button.text)
            elsif button.type
              Vue.createElement(button.type, {props: button.attrs})
            end
          end
        end
      end

      #
      # Next link
      #
      link = @@item.next

      if @@options.traversal == :queue
        while link and not link.ready_for_review(User.initials)
          link = link.next
        end
        link ||= {href: 'queue', title: 'Queue'}
      elsif @@options.traversal == :shepherd
        while link and link.shepherd != @@item.shepherd
          link = link.next
        end
        link ||= {href: "shepherd/#{@@item.shepherd}", title: 'shepherd'}
      elsif @@options.traversal == :flagged
        prefix = 'flagged/'
        while link and not link.flagged
          if Minutes.started and link.index
            prefix = ''
            break
          else
            link = link.next
          end
        end
        link ||= {href: "flagged", title: 'Flagged'}
      elsif Minutes.started and link and link.attach == 'A'
        while link and not link.flagged and link.attach =~ /^[A-Z]/
          link = link.next
        end

        prefix = 'flagged/' if link and link.attach =~ /^[A-Z]/
      end

      if link
        prefix = '' unless  link.attach =~ /^[A-Z]/
        _Link.nextlink.navbar_brand text: link.title, rel: 'next', 
         href: "#{prefix}#{link.href}", class: link.color
      elsif @@item.prev or @@item.next
        # without this, Chrome will sometimes make the footer too tall
        _a.nextarea.navbar_brand
      end
    end
  end
end
