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

  def componentWillReceiveProps()
    if Main.view and !Main.view.showseen()
      @label = 'hide seen'
    else
      @label = 'show seen'
    end
  end

  def click(event)
    Main.view.toggleseen()
    self.componentWillReceiveProps()
  end
end
