class Parts < React
  def initialize
    @selected = nil
    @busy = false
  end

  def render
    # common options for all list items
    options = {
      draggable: 'true',
      onDragStart: self.dragStart,
      onDragEnter: self.dragEnter,
      onDragOver: self.dragOver,
      onDragLeave: self.dragLeave,
      onDragEnd: self.dragEnd,
      onDrop: self.drop,
      onContextMenu: self.menu,
    }

    _ul @@attachments, ref: 'attachments' do |attachment|
      _li options do
        _a attachment.name, href: attachment.name, target: 'content',
          draggable: 'false'
      end
    end

    _ul.contextMenu ref: 'menu' do
      _li 'burst'
      _li 'file'
      _li 'delete'
    end

    _img.spinner src: '../../rotatingclock-slow2.gif' if @busy
  end

  # disable context menu and register mouse and keyboard handlers
  def componentDidMount()
    $menu.style.display = :none
    window.onmousedown = self.click

    # register keyboard handler on parent window and all frames
    window.parent.onkeydown = self.keydown
    frames = window.parent.frames
    for i in 0...frames.length
      frames[i].onkeydown=self.keydown
    end
  end

  # position and show context menu
  def menu(event)
    @selected = event.currentTarget.textContent
    $menu.style.left = event.clientX + 'px'
    $menu.style.top = event.clientY + 'px'
    $menu.style.position = :absolute
    $menu.style.display = :block
    event.preventDefault()
  end

  # hide context menu whenever a click is received outside the menu
  def click(event)
    target = event.target
    while target
      return if target.class == 'contextMenu'
      target = target.parentNode
    end
    console.log 'click'
    $menu.style.display = :none
  end

  def keydown(event)
    if event.keyCode == 8 or event.keyCode == 46 # backspace or delete
      if event.metaKey
        @busy = true
        event.stopPropagation()

        pathname = window.parent.location.pathname
        HTTP.delete(pathname) do
          Status.pushDeleted pathname
          window.parent.location.href = '../..'
        end
      end
    end
  end

  #
  # drag/drop support.  Note: support varies by browser (in particular,
  # when events are called and whether or not a particular event has
  # access to dataTransfer data.)  Accordingly, the below is coded in
  # a way that is mildly redundant and uses React.js state data in lieu of
  # dataTransfer.  Oddly, with some browsers, drag and drop isn't possible
  # without setting something in dataTransfer, so that data is set too, even
  # though it is not used.
  #

  # start by capturing the 'href' attribute
  def dragStart(event)
    @drag = event.currentTarget.querySelector('a').getAttribute('href')
    event.dataTransfer.setData('text', @drag)
  end

  # show item as valid drop target when a dragged element is over it
  def dragEnter(event)
    href = event.currentTarget.querySelector('a').getAttribute('href')
    if @drag and @drag != href
      event.currentTarget.classList.add 'drop-target'
    end
  end

  # check for valid drag/drop operations (different href)
  def dragOver(event)
    href = event.currentTarget.querySelector('a').getAttribute('href')
    if @drag and @drag != href
      event.currentTarget.classList.add 'drop-target'
      event.preventDefault()
    end
  end

  # unmark item as selected when a dragged element is no longer over it
  def dragLeave(event)
    event.currentTarget.classList.remove 'drop-target'
  end

  # complete drop operation
  def drop(event)
    href = event.currentTarget.querySelector('a').getAttribute('href')
    alert("drop #{@drag} onto #{href}")
    @drag = nil
    event.currentTarget.classList.remove 'drop-target'
    event.preventDefault()
  end

  # cancel drag operation
  def dragEnd(event)
    @drag = nil
  end
end
