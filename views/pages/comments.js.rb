#
# A page showing all comments present across all agenda items
# Conditionally hide comments previously marked as seen.
#

class Comments < React
  def initialize
    @showseen = false
  end

  def toggleseen()
    @showseen = ! @showseen
  end

  def showseen
    return @showseen
  end

  def render
    found = false

    Agenda.index.each do |item|
      next if item.comments.empty?

      if @showseen
        visible = item.comments
      else
        # exclude comments we have seen before
	visible = []
	seen = Pending.seen[item.attach] || []
	item.comments.each do |comment|
	  visible << comment unless seen.include? comment
	end
      end

      unless visible.empty?
        found = true

	_section do
	  _h4 {_Link text: item.title, href: item.href}

	  item.comments.each do |comment|
	    _pre.comment comment
	  end
	end
      end
    end

    unless found
      _p do
        if Pending.seen.keys().empty?
          _em 'No comments found'
        else
          _em 'No new comments found'
        end
      end
    end
  end
end
