class Parts < React
  def initialize
    @selected = nil
    @busy = false
    @attachments = []
    @drag = nil
    @form = nil
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

    # list of attachments
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

    # context menu that displays when you 'right click' an attachment
    _ul.contextMenu do
      _li "\u2704 burst", onMouseDown: self.burst
      _li.divider
      _li "\u21B7 right", onMouseDown: self.rotate_attachment
      _li "\u21c5 flip", onMouseDown: self.rotate_attachment
      _li "\u21B6 left", onMouseDown: self.rotate_attachment
      _li.divider
      _li "\u2716 delete", onMouseDown: self.delete_attachment
    end

    # filing options
    if @selected
      _table.doctype do
        _tr do
          _td do
            _input type: 'radio', name: 'doctype', value: 'icla',
              onClick: -> {@form = ICLA}
          end

          _td do
            _input type: 'radio', name: 'doctype', value: 'grant',
              onClick: -> {@form = Grant}
          end

          _td do
            _input type: 'radio', name: 'doctype', value: 'ccla',
              onClick: -> {@form = CCLA}
          end

          _td do
            _input type: 'radio', name: 'doctype', value: 'nda',
              onClick: -> {@form = NDA}
          end

          _td do
            _input type: 'radio', name: 'doctype', value: 'mem',
              onClick: -> {@form = MemApp}
          end
        end

        _tr do
          _td 'icla'
          _td 'grant'
          _td 'ccla'
          _td 'nda'
          _td 'mem'
        end
      end

      if @form
        React.createElement @form, headers: @@headers, submit: self.submit
      end
    end

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
    menu.style.position = :absolute
    menu.style.display = :block

    bodyRect = document.body.getBoundingClientRect()
    menuRect = menu.getBoundingClientRect()
    position = {x: event.clientX, y: event.clientY}

    if position.x + menuRect.width > bodyRect.width
      position.x -= menuRect.width if position.x >= menuRect.width
    end

    if position.y + menuRect.height > bodyRect.height
      position.y -= menuRect.height if position.y >= menuRect.height
    end

    menu.style.left = position.x + 'px'
    menu.style.top = position.y + 'px'
    event.preventDefault()
  end

  # form submission - handles all forms
  def submit(event)
    event.preventDefault()
    form = event.currentTarget

    data = {}
    Array(form.querySelectorAll('input')).each do |field|
      data[field.name] = field.value if field.name
    end

    @busy = true
    HTTP(post form.action, data).then {|response|
      @busy = false
      alert response.result
    }.catch {|error|
      alert error
      @busy = false
    }
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

  # clicking on an attachment selects it
  def select(event)
    @selected = event.currentTarget.querySelector('a').getAttribute('href')
  end

  # handle keyboard events
  def keydown(event)
    if event.keyCode == 8 or event.keyCode == 46 # backspace or delete
      if event.metaKey or event.ctrlKey
        @busy = true
        event.stopPropagation()

        pathname = window.parent.location.pathname
        HTTP.delete(pathname).then {
          Status.pushDeleted pathname
          window.parent.location.href = '../..'
        }.catch {|error|
          alert error
          @busy = false
        }
      end
    end
  end

  # burst a PDF into individual pages
  def burst(event)
    data = {
      selected: @selected,
      message: window.parent.location.pathname
    }

    @busy = true
    HTTP.post('../../actions/burst', data).then {|response|
      @attachments = response.attachments
      @selected = response.selected
      @busy = false
      window.parent.frames.content.location.href=response.selected
    }.catch {|error|
      alert error
      @busy = false
    }
  end

  # burst a PDF into individual pages
  def delete_attachment(event)
    data = {
      selected: @selected,
      message: window.parent.location.pathname
    }

    @busy = true
    HTTP.post('../../actions/delete-attachment', data).then {|response|
      if response.attachments and not response.attachments.empty?
        @attachments = response.attachments
        @busy = false
        window.parent.frames.content.location.href='_body_'
      else
        window.parent.location.href = '../..'
      end
    }.catch {|error|
      alert error
      @busy = false
    }
  end

  # rotate an attachment
  def rotate_attachment(event)
    message = window.parent.location.pathname

    data = {
      selected: @selected,
      message: message,
      direction: event.currentTarget.textContent
    }

    @busy = true
    HTTP.post('../../actions/rotate-attachment', data).then {|response|
      @attachments = response.attachments
      @selected = response.selected
      @busy = false

      # reload attachment in content pane
      window.parent.frames.content.location.href = response.selected
    }.catch {|error|
      alert error
      @busy = false
    }
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
    HTTP.post('../../actions/drop', data).then {|response| 
      @attachments = response.attachments
      @selected = response.selected
      @busy = false
      target.classList.remove 'drop-target'
      window.parent.frames.content.location.href=response.selected
    }.catch {|error|
      alert error
      @busy = false
    }
  end

  # cancel drag operation
  def dragEnd(event)
    @drag = nil
  end
end
