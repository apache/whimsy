#
# Respond to swipes
#

class Touch
  def self.initEventHandlers()
    threshold = 150 # minimum distance required to be considered a swipe
    limit = 100 # max distance in other direction
    allowedTime = 500 # maximum time

    startX = 0
    startY = 0
    startTime = 0

    document.body.addEventListener :touchstart do |event|
      touchobj = event.changedTouches[0]
      startX = touchobj.pageX
      startY = touchobj.pageY
      startTime = Date.new().getTime()
    end

    document.body.addEventListener :touchend do |event|
      elapsed = startTime - Date.new().getTime()
      return if elapsed > allowedTime

      touchobj = event.changedTouches[0]
      distX = startX - touchobj.pageX
      distY = startY - touchobj.pageY

      swipedir = 'none'

      if Math.abs(distX) >= threshold and Math.abs(distY) <= limit
        swipedir = (distX < 0) ? 'left' : 'right'
      elsif Math.abs(distY) >= threshold and Math.abs(distX) <= limit
        swipedir = (distY < 0) ? 'up' : 'down'
      end

      case swipedir
      when 'left'
        link = document.querySelector("a[rel=prev]")
        link.click() if link

      when 'right'
        link = document.querySelector("a[rel=next]")
        link.click() if link

      when 'up', 'down'
        Main.navigate history.state.path.sub(/[^\/]\/?$/, '') || '.'
      end
    end

  end
end
