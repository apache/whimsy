#
# Respond to keyboard events
#

class Keyboard
  def self.initEventHandlers()

    # keyboard navigation (unless on the search screen)
    def (document.body).onkeydown(event)
      return if event.metaKey or event.ctrlKey or event.altKey or
        document.getElementById('search-text') or
        document.querySelector('.modal.in') or
        %w(input textarea).include? document.activeElement.tagName.downcase()

      if event.keyCode == 37 # '<-'
        link = document.querySelector("a[rel=prev]")
        if link
          link.click()
          return false
        end
      elsif event.keyCode == 39 # '->'
        link = document.querySelector("a[rel=next]")
        if link
          link.click()
          return false
        end
      elsif event.keyCode == 13 # 'enter'
        link = document.querySelector(".default")
        Main.navigate link.getAttribute('href') if link
        return false
      elsif event.keyCode == 'C'.ord
        link = document.getElementById("comments")
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
      elsif event.keyCode == 'M'.ord
        Main.navigate 'missing'
        return false
      elsif event.keyCode == 'N'.ord
        document.getElementById("nav").click()
        return false
      elsif event.keyCode == 'A'.ord
        Main.navigate '.'
        return false
      elsif event.keyCode == 'S'.ord
        if event.shiftKey
          User.role = :secretary
          Main.refresh()
        else
          link = document.getElementById("shepherd")
          Main.navigate link.getAttribute('href') if link
        end
        return false
      elsif event.keyCode == 'X'.ord
        if Main.item.attach and Minutes.started and not Minutes.complete
          Chat.changeTopic user: User.userid, link: Main.item.href,
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
        Header.clock_counter += 1
        Main.refresh()
        post 'refresh', agenda: Agenda.file do |response|
          Header.clock_counter -= 1
          Agenda.load response.agenda, response.digest
          Main.refresh()
        end
        return false
      elsif event.keyCode == '='.ord or event.keyCode == 187 # "="
        Main.navigate "cache/"
        return false
      end
    end

  end
end
