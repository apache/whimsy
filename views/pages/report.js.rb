class Report < React
  def render
    _section.flexbox do
      _section do
        _pre.report do
          _p {_em 'Missing'} if @@data.missing
          _ @@data.text
        end
      end

      _section do
        unless @@data.comments.empty?
          _h3.comments! 'Comments'
          @@data.comments.each do |comment|
            _pre.comment comment
          end
        end

        if @@data.pending
          _h3.comments! 'Pending Comment'
          _pre.comment (Pending.initials || Server.initials) + ': ' + 
            @@data.pending
        end

        if @@data.title != 'Action Items' and @@data.actions
          _h3.comments! 'Action Items'
          @@data.actions.each do |action|
            _pre.comment action
          end
        end
      end
    end
  end
end
