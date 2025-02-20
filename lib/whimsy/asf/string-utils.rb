# String utilities

# derived from agenda/helpers/string.rb
# converted to utility module rather than patching the String class

# This addon must be required before use

module ASFString
  # wrap a text block containing long lines
  def self.word_wrap(text, line_width=80)
    text.split("\n").collect do |line|
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
  def self.reflow(text, indent=4, len=80)
    text.strip.split(/\n\s*\n/).map {|line|
      line.gsub!(/\s+/, ' ')
      line.strip!
      word_wrap(line, len - indent).gsub(/^/, ' ' * indent)
    }.join("\n\n")
  end

  # replace matched expressions with the result of the block being called
  def self.mreplace(text, regexp, &block)
    matches = []
    off = 0
    while text[off..-1] =~ regexp
      matches << [off, $~]
      off += $~.end($~.size - 1)
    end
    raise 'unmatched' if matches.empty?

    matches.reverse.each do |offset, match|
      slice = text[offset...-1]
      send = (1...match.size).map {|i| slice[match.begin(i)...match.end(i)]}
      if send.length == 1
        recv = block.call(send.first)
        text[offset + match.begin(1)...offset + match.end(1)] = recv
      else
        recv = block.call(*send)
        next unless recv
        (1...match.size).map {|i| [match.begin(i), match.end(i), i - 1]}.sort.
          reverse.each do |start, fin, i|
          text[offset + start...offset + fin] = recv[i]
        end
      end
    end
    text
  end

  # fix encoding errors
  def self.fix_encoding(text)

    if text.encoding == Encoding::BINARY
      return text.encode('utf-8', invalid: :replace, undef: :replace)
    end
    return text

  end
end

if __FILE__ == $0
  txt = "
  The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog.

  The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog.

  The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog. The quick brown fox jumped over the lazy dog.
  "
  # puts txt
  puts ASFString.word_wrap(txt)
  puts ASFString.reflow(txt)
  text="\x05\x00\x68\x65\x6c\x6c\x6f"
  text.force_encoding(Encoding::BINARY)
  puts ASFString.fix_encoding(text)
end
