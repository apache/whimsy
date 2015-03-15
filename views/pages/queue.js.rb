#
# A page showing all queued approvals and comments, as well as items
# that are ready for review.
#

class Queue < React
  def render
    _div.col_xs_12 do

      # Approvals
      _h4 'Approvals'
      _p.col_xs_12 do
        @approvals.each_with_index do |item, index|
          _span ', ' if index > 0
          _Link text: item.title, href: item.href
        end
        _em 'None.' if @approvals.empty?
      end

      # Rejected
      unless @rejected.empty?
        _h4 'Rejected'
        _p.col_xs_12 do
          @rejected.each_with_index do |item, index|
            _span ', ' if index > 0
            _Link text: item.title, href: item.href
          end
        end
      end

      # Comments
      _h4 'Comments'
      _dl.dl_horizontal @comments do |item|
        _dt do
          _Link text: item.title, href: item.href
        end
        _dd do
          item.pending.split("\n\n").each do |paragraph|
            _p paragraph
          end
        end
      end
      _p.col_xs_12 {_em 'None.'} if @comments.empty?

      # Ready
      unless @ready.empty?
        _div.row.col_xs_12 { _hr }

        _h4 'Ready for review'
        _p.col_xs_12 do
          @ready.each_with_index do |item, index|
            _span ', ' if index > 0
            _Link text: item.title, href: item.qhref,
              class: ('default' if index == 0)
          end
        end
      end
    end
  end

  # set state on first load
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # determine approvals, rejected, comments, and ready
  def componentWillReceiveProps()
    @approvals = []
    @rejected = []
    @comments = []
    @ready = []

    Agenda.index.each do |item|
      if Pending.comments[item.attach]
        @comments << item
      end
    end
  end
end
