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

      _dt 'ctrl'
      _dd do
        _ 'On report pages, changes '
        _b 'approve'
        _ ' buttons to '
        _b 'reject'
      end

      _dt '?'
      _dd 'Help (this page)'
    end

    _h3 'Color Legend'
    _ul do
      _li.missing 'Report missing, rejected, or has formatting errors'
      _li.available 'Report present, not eligible for pre-reviews'
      _li.ready 'Report present, ready for (more) review(s)'
      _li.reviewed 'Report has sufficient pre-approvals'
      _li.commented 'Report has been approved, with comments'
    end

    if Server.userid == 'rubys'
      _h3 'Mode'
      _form.mode! do
        %w(Secretary Director Guest).each do |mode|
          _div do
            _input mode, type: 'radio', name: 'mode', value: mode.downcase 
          end
        end
      end
    end
  end
end
