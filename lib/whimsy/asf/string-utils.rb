# update String class to add some useful methods
# These are prefixed with asf_ to avoid clashing with built-in methods
# derived from agenda/helpers/string.rb

# This addon must be required before use

class String
  # wrap a text block containing long lines
  def asf_word_wrap(line_width=80)
    self.split("\n").collect do |line|
      if line.length > line_width
        line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip
      else
        line
      end
    end * "\n"
  end

  # reflow an indented block
  # indent = number of spaces to indent by (default 4)
  # len = length of line including the indent (default 80)
  def asf_reflow(indent=4, len=80)
    strip.split(/\n\s*\n/).map {|line|
      line.gsub!(/\s+/, ' ')
      line.strip!
      line.asf_word_wrap(len - indent).gsub(/^/, ' ' * indent)
    }.join("\n\n")
  end

  # replace matched expressions with the result of the block being called
  def asf_mreplace(regexp, &block)
    matches = []
    off = 0
    while self[off..-1] =~ regexp
      matches << [off, $~]
      off += $~.end($~.size - 1)
    end
    raise 'unmatched' if matches.empty?

    matches.reverse.each do |offset, match|
      slice = self[offset...-1]
      send = (1...match.size).map {|i| slice[match.begin(i)...match.end(i)]}
      if send.length == 1
        recv = block.call(send.first)
        self[offset + match.begin(1)...offset + match.end(1)] = recv
      else
        recv = block.call(*send)
        next unless recv
        (1...match.size).map {|i| [match.begin(i), match.end(i), i - 1]}.sort.
          reverse.each do |start, fin, i|
          self[offset + start...offset + fin] = recv[i]
        end
      end
    end
    self
  end

  # fix encoding errors
  def asf_fix_encoding
    result = self

    if encoding == Encoding::BINARY
      result = encode('utf-8', invalid: :replace, undef: :replace)
    end

    result
  end
end

if __FILE__ == $0
  txt = "
  The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog.

  The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog.

  The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog.
  "
  # puts txt
  puts txt.asf_word_wrap
  puts txt.asf_reflow
end
