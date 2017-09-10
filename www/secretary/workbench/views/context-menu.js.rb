#
# Context menu with actions to apply to an attachment
#

class ContextMenu < Vue
  def render
    # context menu that displays when you 'right click' an attachment
    _ul.contextMenu do
      _li "\u2704 burst", onMousedown: self.burst
      _li.divider
      _li "\u21B7 right", onMousedown: self.rotate_attachment
      _li "\u21c5 flip", onMousedown: self.rotate_attachment
      _li "\u21B6 left", onMousedown: self.rotate_attachment
      _li.divider
      _li "\u2716 delete", onMousedown: self.delete_attachment
    end
  end

  # disable context menu
  def mounted()
    document.querySelector('.contextMenu').style.display = :none
  end

  # position and show context menu
  def self.show(event)
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

  # hide context menu whenever a click is received outside the menu
  def self.hide(event)
    target = event && event.target
    while target
      return if target.class == 'contextMenu'
      target = target.parentNode
    end
    document.querySelector('.contextMenu').style.display = :none
  end

  # burst a PDF into individual pages
  def burst(event)
    data = {
      selected: @@parts.state.menu,
      message: window.parent.location.pathname
    }

    @@parts.setState busy: true
    HTTP.post('../../actions/burst', data).then {|response|
      @@parts.setState attachments: response.attachments,
        selected: response.selected, busy: false, menu: nil
      window.parent.frames.content.location.href=response.selected
      ContextMenu.hide()
    }.catch {|error|
      alert error
      @@parts.setState busy: false, menu: nil
      ContextMenu.hide()
    }
  end

  # burst a PDF into individual pages
  def delete_attachment(event)
    data = {
      selected: @@parts.state.menu,
      message: window.parent.location.pathname
    }

    @@parts.setState busy: true
    HTTP.post('../../actions/delete-attachment', data).then {|response|
      if response.attachments and not response.attachments.empty?
        @@parts.setState attachments: response.attachments, busy: false,
          menu: nil
        window.parent.frames.content.location.href='_body_'
        ContextMenu.hide()
      else
        window.parent.location.href = '../..'
      end
    }.catch {|error|
      alert error
      @@parts.setState busy: false, menu: nil
      ContextMenu.hide()
    }
  end

  # rotate an attachment
  def rotate_attachment(event)
    message = window.parent.location.pathname

    data = {
      selected: @@parts.state.menu,
      message: message,
      direction: event.currentTarget.textContent
    }

    @@parts.setState busy: true
    HTTP.post('../../actions/rotate-attachment', data).then {|response|
      @@parts.setState attachments: response.attachments,
        selected: response.selected, busy: false, menu: nil

      # reload attachment in content pane
      window.parent.frames.content.location.href = response.selected

      ContextMenu.hide()
    }.catch {|error|
      alert error
      @@parts.setState busy: false, menu: nil
      ContextMenu.hide()
    }
  end
end
