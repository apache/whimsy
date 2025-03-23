#!/usr/bin/env ruby

# Parse foundation/members.md from main website

require 'net/http'

URL = 'https://raw.githubusercontent.com/apache/www-site/refs/heads/main/content/foundation/members.md'

def parse_section(section, status)
  section.each do |line|
      if line =~ %r{^\|\s+(\S+)\s+\|}
        uid = $1
        unless %w{Id ?}.include? uid
          yield [status, uid]
        end
      end
    end
end

def parse_members(&block)
  response = Net::HTTP.get_response(URI(URL))
  response.value() # Raises error if not OK
  content = response.body

  content.split("\n").slice_before(/^##/).each do |slice|
    title = slice.first
    if title =~ %r{^## (\S+) Members}
      parse_section(slice, $1, &block) unless $1 == 'Deceased'
    end
  end
end

if __FILE__ == $0
  parse_members do |status, id|
    p [status, id]
  end
end
