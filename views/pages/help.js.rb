class Help < React
  def render
    _h3 'Keyboard shortcuts'
    _dl.dl_horizontal do
      _dt 'left arrow'
      _dd 'previous page'

      _dt 'right arrow'
      _dd 'next page'

      _dt 'enter'
      _dd 'On Shepherd and Queue pages, go to the first report listed'

      _dt 'C'
      _dd 'Scroll to comment section (if any)'

      _dt 'I'
      _dd 'Toggle Info dropdown'

      _dt 'N'
      _dd 'Toggle Navigation dropdown'

      _dt 'A'
      _dd 'Navigate to the overall agenda page'

      _dt 'Q'
      _dd 'Show queued approvals/comments'

      _dt 'S'
      _dd 'Show shepherded items (and action items)'

      _dt 'F'
      _dd 'Show flagged items'

      _dt '?'
      _dd 'Help (this page)'
    end

    _h3 'Color Legend'
    _ul do
      _li.missing 'Report missing, rejected, or has formatting errors'
      _li.available 'Report present, not eligible for pre-reviews'
      _li.ready 'Report present, ready for (more) review(s)'
      _li.reviewed 'Report has sufficient pre-approvals'
      _li.commented 'Report has been flagged for discussion'
    end

    if %w(test rubys).include? Server.userid
      _h3 'Role'
      _form.role! do
        %w(Secretary Director Guest).each do |role|
          _div do
            _input role, type: 'radio', name: 'role', value: role.downcase(),
              checked: role.downcase() == Server.role, onChange: self.setRole
          end
        end
      end
    end
  end

  def setRole(event)
    Server.role = event.target.value
    Main.refresh()
  end
end
