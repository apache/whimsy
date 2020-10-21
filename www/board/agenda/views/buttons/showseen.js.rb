#
# Show/hide seen items
#
class ShowSeen < Vue
  def initialize
    @label = 'show seen'
  end

  def render
    _button.btn.btn_primary @label, onClick: self.click
  end

  def created()
    self.changeLabel()
  end

  def click(event)
    EventBus.emit :toggleseen
    self.changeLabel()
  end

  def changeLabel()
    if Main.view and !Main.view.showseen()
      @label = 'hide seen'
    else
      @label = 'show seen'
    end
  end
end
