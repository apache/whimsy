class Parts < React
  def initialize
    @selected = nil
    @busy = false
    @attachments = []
    @drag = nil
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
      onClick: self.select
    }

    _ul @attachments, ref: 'attachments' do |attachment|
      if attachment == @drag
        options[:className] = 'dragging'
      elsif attachment == @selected
        options[:className] = 'selected'
      else
        options[:className] = nil
      end

      _li options do
        _a attachment, href: attachment, target: 'content', draggable: 'false'
      end
    end

    _ContextMenu

    _img.spinner src: '../../rotatingclock-slow2.gif' if @busy
  end

  # initialize attachments list with the data from the server
  def componentWillMount()
    @attachments = @@attachments
  end

  # disable context menu and register mouse and keyboard handlers
  def componentDidMount()
    document.querySelector('.contextMenu').style.display = :none
    window.onmousedown = self.window_click

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
    menu = document.querySelector('.contextMenu')
    menu.style.left = event.clientX + 'px'
    menu.style.top = event.clientY + 'px'
    menu.style.position = :absolute
    menu.style.display = :block
    event.preventDefault()
  end

  # hide context menu whenever a click is received outside the menu
  def window_click(event)
    target = event.target
    while target
      return if target.class == 'contextMenu'
      target = target.parentNode
    end
    document.querySelector('.contextMenu').style.display = :none
  end

  def select(event)
    @selected = event.currentTarget.querySelector('a').getAttribute('href')
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
    target = event.currentTarget
    href = target.querySelector('a').getAttribute('href')
    event.preventDefault()

    data = {
      source: @drag,
      target: href,
      message: window.parent.location.pathname
    }

    @busy = true
    @drag = nil
    HTTP.post '../../actions/drop', data do |response| 
      @attachments = response.attachments
      @selected = response.selected
      @busy = false
      target.classList.remove 'drop-target'
      window.parent.frames.content.location.href=response.selected
    end
  end

  # cancel drag operation
  def dragEnd(event)
    @drag = nil
  end
end
