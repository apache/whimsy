require 'yaml'

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

# apply comments to an agenda file
def apply_comments(agenda_file, update_file, initials)
  agenda = File.read(agenda_file)

  updates = YAML.load_file(update_file)
  approved = updates['approved']
  comments = updates['comments']

  pattern = /
      \s{7}See\sAttachment\s\s?(\w+)[^\n]*?\s+
      \[\s[^\n]*\s*approved:\s*?(.*?)
      \s*comments:(.*?)\n\s{9}\]
    /mx

  agenda.gsub!(pattern) do |match|
    attachment, approvals = $1, $2

    if approved.include? attachment
      approvals = approvals.strip.split(/(?:,\s*|\s+)/)
      if approvals.include? initials
        # do nothing
      elsif approvals.empty?
        match[/approved:(\s*)\n/, 1] = " #{initials}"
      else
        match[/approved:.*?()\n/, 1] = ", #{initials}"
      end
    end

    if comments.include? attachment
      width = 79-13-initials.length
      text = comments[attachment].reflow(13+initials.length, width)
      text[/ *(#{' '*(initials.length+2)})/,1] = "#{initials}: "
      match[/\n()\s{9}\]/,1] = "#{text}\n"
    end

    match
  end

  File.open(agenda_file, 'w') {|file| file.write(agenda)}
end

if __FILE__ == $0
  apply_comments *ARGV
end
