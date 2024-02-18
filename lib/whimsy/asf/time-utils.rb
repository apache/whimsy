# Time/date utilities

# This addon must be required before use

module ASFTime
  # Convert seconds to number of days, hours or minutes
  # Intended for countdown-style displays
  def self.secs2text(secs)
    m = secs / 60
    s = secs - m*60
    h = m / 60
    m = m - h*60
    d = h / 24
    h = h - d*24
    return "#{d} days" if d > 0
    return "#{h} hours" if h > 0
    return "#{m} minutes"
  end
end

if __FILE__ == $0
  p ASFTime.secs2text(120)
  p ASFTime.secs2text(23101)
  p ASFTime.secs2text(223911)
end
