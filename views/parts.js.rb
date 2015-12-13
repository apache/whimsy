class Parts < React
  def initialize
    @selected = nil
  end

  def render
    _ul @@attachments do |attachment|
      _li onContextMenu: self.menu do
        _a attachment.name, href: attachment.name, target: 'content'
      end
    end

    _ul.contextMenu ref: 'menu' do
      _li 'burst'
      _li 'file'
      _li 'delete'
    end
  end

  def componentDidMount()
    $menu.style.display = :none
  end

  def menu(event)
    @selected = event.currentTarget.textContent
    $menu.style.left = event.clientX + 'px'
    $menu.style.top = event.clientY + 'px'
    $menu.style.position = :absolute
    $menu.style.display = :block
    event.preventDefault()
  end
end
