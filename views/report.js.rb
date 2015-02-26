class Report < React
  def render
    _section.flexbox do
      _section do
        _pre.report do
          _em 'Missing' if @@data.missing
          _ @@data.text
        end
      end

      if @@data.comments
        _section do
          _h3.comments! 'Comments'
          @@data.comments.each do |comment|
            _pre.comment comment
          end
        end
      end
    end
  end
end
