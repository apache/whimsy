#!/usr/bin/env ruby

# Script to normalise committee-info.txt so there are at least 2 spaces between fields in PMC section

# Default to UTF-8 for IO
ENV['LANG'] ||= 'en_US.UTF-8'
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

if __FILE__ == $0
  CIN = ARGV.shift || '/srv/svn/board/committee-info.txt'
  OUT = ARGV.shift || '/srv/svn/board/committee-info.tmp'

  File.open(OUT, 'w') do |out|
    File.open(CIN, 'r').slice_before{|l| l.start_with? '* '}.each do |lines|
      head = lines.shift
      out.write(head)
      unless head.start_with? '* ' # ignore initial block
        lines.each {|l| out.write(l)}
        next
      end
      # sort to allow for trailing blanks and ===
      maxname = 0
      maxemail = 0
      block = []
      lines.sort_by{|k| k == "\n" ? '=' : k}.each do |line|
        if line =~ %r{^    (\S.+?)(<\S+>\s+)(\[.+)}
          name = $1
          email = $2
          date = $3
          # out.write("    #{name.ljust(NAMEL)}  #{email.ljust(MAILL)}  #{date}\n")
          name += ' ' unless name.end_with? '  ' # must have at least 2 spaces
          maxname = name.size if name.size > maxname
          email += ' ' unless email.end_with? '  ' # must have at least 2 spaces
          maxemail = email.size if email.size > maxemail
          block << [name, email, date]
        else
          block << line
          p line if line.start_with? '    ' # should have matched above
        end
      end
      block.each do |line|
        if String === line
          out.write(line)
        else
          name, email, date = line
          out.write("    #{name.ljust(maxname)}#{email.ljust(maxemail)}#{date}\n")
        end
      end
    end

  end
  puts 'Done'
end