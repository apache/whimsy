#
# Respond to swipes
#

class Touch
  def self.initEventHandlers()
    # configuration
    threshold = 150 # minimum distance required to be considered a swipe
    limit = 100 # max distance in other direction
    allowedTime = 500 # maximum time

    # state
    startX = 0
    startY = 0
    startTime = 0

    # capture start of swipe
    window.addEventListener :touchstart do |event|
      touchobj = event.changedTouches[0]
      startX = touchobj.pageX
      startY = touchobj.pageY
      startTime = Date.new().getTime()
    end

    # process end of swipe
    window.addEventListener :touchend do |event|
      # ignore if a touch lasted too long
      elapsed = Date.new().getTime() - startTime
      return if elapsed > allowedTime

      # ignore if a modal dialog is active
      return if document.querySelector('.modal.in')

      # compute distances
      touchobj = event.changedTouches[0]
      distX = touchobj.pageX - startX
      distY = touchobj.pageY - startY

      # compute direction
      swipedir = 'none'

      if Math.abs(distX) >= threshold and Math.abs(distY) <= limit
        swipedir = (distX < 0) ? 'left' : 'right'
      elsif Math.abs(distY) >= threshold and Math.abs(distX) <= limit
        swipedir = (distY < 0) ? 'up' : 'down'
      end

      # process swipe event
      case swipedir
      when 'left'
        link = document.querySelector("a[rel=next]")
        link.click() if link

      when 'right'
        link = document.querySelector("a[rel=prev]")
        link.click() if link

      when 'up', 'down'
        path = history.state.path.sub(/[^\/]+\/?$/, '') || '.'
        path = "shepherd/#{Main.item.shepherd}" if path == 'shepherd/queue/'
        path = "flagged" if path == 'flagged/'
        path = "queue" if path == 'queue/'

        Main.navigate path
      end
    end

  end
end
