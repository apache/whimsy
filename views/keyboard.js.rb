#
# Respond to keyboard events
#

class Keyboard
  def self.initEventHandlers()

    # keyboard navigation (unless on the search screen)
    def (document.body).onkeydown(event)
      return if ~'#search-text'[0] or ~'.modal-open'[0] or ~'.modal.in'[0]
      return if not event.altKey and
        %w(input textarea).include? document.activeElement.tagName.downcase()
      return if event.metaKey or event.ctrlKey

      if event.keyCode == 37 # '<-'
        link = ~"a[rel=prev]"[0]
        if link
          link.click()
          return false
        end
      elsif event.keyCode == 39 # '->'
        link = ~"a[rel=next]"[0]
        if link
          link.click()
          return false
        end
      elsif event.keyCode == 13 # 'enter'
        link = ~".default"[0]
        Main.navigate link.getAttribute('href') if link
        return false
      elsif event.keyCode == 'C'.ord
        link = ~"#comments"[0]
        if link
          jQuery('html, body').animate({scrollTop: link.offsetTop}, :slow);
        else
          Main.navigate 'comments'
        end
        return false
      elsif event.keyCode == 'I'.ord
        info = document.getElementById("info")
        info.click() if info
        return false
      elsif event.keyCode == 'N'.ord
        ~"#nav".click
        return false
      elsif event.keyCode == 'A'.ord
        Main.navigate '.'
        return false
      elsif event.keyCode == 'S'.ord
        link = ~"#shepherd"[0]
        Main.navigate link.getAttribute('href') if link
        return false
      elsif event.keyCode == 'X'.ord
        if Main.item.attach and Minutes.started and not Minutes.complete
          Chat.changeTopic user: Server.userid, link: Main.item.href,
            text: "current topic: #{Main.item.title}"
          return false
        end
      elsif event.keyCode == 'Q'.ord
        Main.navigate "queue"
        return false
      elsif event.keyCode == 'F'.ord
        Main.navigate "flagged"
        return false
      elsif event.keyCode == 'B'.ord
        Main.navigate "backchannel"
        return false
      elsif event.shiftKey and event.keyCode == 191 # "?"
        Main.navigate "help"
        return false
      elsif event.keyCode == 'R'.ord
        clock_counter += 1
        Main.refresh()
        post 'refresh', agenda: Agenda.file do |response|
          clock_counter -= 1
          Agenda.load response.agenda
          Main.refresh()
        end
        return false
      end
    end

  end
end
