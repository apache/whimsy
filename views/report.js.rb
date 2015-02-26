class Report < React
  def render
    _section.flexbox do
      if @@data.missing
        _pre.report do
          _em 'Missing'
        end
      else
        _pre @@data.text
      end
    end
  end
end
