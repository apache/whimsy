class Report < React
  def render
    _section.flexbox do
      _section do
        _pre.report do
          _p {_em 'Missing'} if @@item.missing
          _ @@item.text
        end
      end

      _section do
        unless @@item.comments.empty?
          _h3.comments! 'Comments'
          @@item.comments.each do |comment|
            _pre.comment comment
          end
        end

        if @@item.pending
          _h3.comments! 'Pending Comment'
          _pre.comment (Pending.initials || Server.initials) + ': ' + 
            @@item.pending
        end

        if @@item.title != 'Action Items' and @@item.actions
          _h3.comments! 'Action Items'
          @@item.actions.each do |action|
            _pre.comment action
          end
        end
      end
    end
  end
end
