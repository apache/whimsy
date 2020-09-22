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

  # replace matched expressions with the result of the block being called
  def mreplace regexp, &block
    matches = []
    offset = 0
    while self[offset..-1] =~ regexp
      matches << [offset, $~]
      offset += $~.end($~.size - 1)
    end
    raise 'unmatched' if matches.empty?

    matches.reverse.each do |offset, match|
      slice = self[offset...-1]
      send = (1...match.size).map {|i| slice[match.begin(i)...match.end(i)]}
      if send.length == 1
        recv = block.call(send.first)
        self[offset+match.begin(1)...offset+match.end(1)] = recv
      else
        recv = block.call(*send)
        next unless recv
        (1...match.size).map {|i| [match.begin(i), match.end(i), i-1]}.sort.
          reverse.each do |start, fin, i|
          self[offset+start...offset+fin] = recv[i]
        end
      end
    end
    self
  end

  # fix encoding errors
  def fix_encoding
    result = self

    if encoding == Encoding::BINARY
      result = encode('utf-8', invalid: :replace, undef: :replace)
    end

    result
  end
end
