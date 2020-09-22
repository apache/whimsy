#
# Layout footer consisting of a previous link, any number of buttons,
# followed by a next link.
#
# Overrides previous and next links when traversal is queue, shepherd, or
# Flagged.  Injects the flagged items into the flow on the meeting day
# (last executive officer <-> first flagged/unapproved/missing &&
#  last flagged/unapproved/missing <-> first Special order)
#

class Footer < Vue
  def render

    meeting_day = Minutes.started || Agenda.meeting_day

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
        while link and link.skippable
          if link.attach =~ /^\d[A-Z]/
            prefix = ''
            break
          else
            link = link.prev
          end
        end

        unless link
          if meeting_day
            link = Agenda.index.find do |item|
              item.next && item.next.attach =~ /^\d+$/
            end
            prefix = ''
          end

          link ||= {href: "flagged", title: 'Flagged'}
        end
      elsif
        meeting_day and @@item.attach =~ /\d/ and
        link and link.attach =~ /^[A-Z]/
      then
        Agenda.index.each do |item|
          if not item.skippable and item.attach =~ /^([A-Z]|\d+$)/
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
        while link and link.skippable
          if meeting_day and link.attach !~ /^(\d+|[A-Z]+)$/
            prefix = ''
            break
          else
            link = link.next
          end
        end
        link ||= {href: "flagged", title: 'Flagged'}
      elsif
        meeting_day and link and
        @@item.attach =~ /^\d[A-Z]/ and link.attach =~ /^\d/
      then
        while link and link.skippable and link.attach =~ /^([A-Z]|\d+$)/
          link = link.next
        end

        prefix = 'flagged/'
      end

      if link
        prefix = '' unless  link.attach =~ /^([A-Z]|\d+$)/
        _Link.nextlink.navbar_brand text: link.title, rel: 'next',
         href: "#{prefix}#{link.href}", class: link.color
      elsif @@item.prev or @@item.next
        # without this, Chrome will sometimes make the footer too tall
        _a.nextarea.navbar_brand
      end
    end
  end
end
