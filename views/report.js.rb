class Report < React
  def render
    _section.flexbox do
      _section do
        _pre.report do
          _em 'Missing' if @@data.missing
          _ @@data.text
        end
      end
    end
  end
end
