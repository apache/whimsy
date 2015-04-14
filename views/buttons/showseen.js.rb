#
# Show/hide seen items
#
class ShowSeen < React
  def initialize
    @label = 'show seen'
  end

  def render
    _button.btn.btn_primary @label, onClick: self.click
  end

  def click(event)
    Main.view.toggleseen()
  end
end
