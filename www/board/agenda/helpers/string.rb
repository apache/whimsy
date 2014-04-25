# reflow string support
class String
  def word_wrap(text, line_width=80)
    text.split("\n").collect do |line|
      line.length > line_width ? 
        line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip : line
    end * "\n"
  end

  def reflow(indent, len)
    strip.split(/\n\s*\n/).map {|line|
      line.gsub!(/\s+/, ' ')
      line.strip!
      word_wrap(line, len).gsub(/^/, ' '*indent)
    }.join("\n\n")
  end
end
