#!/usr/bin/env ruby

print "Content-type: text/plain\r\n\r\n"

#print ENV.inspect

ENV.sort.each do |k,v|
  if k.eql? 'HTTP_AUTHORIZATION'
      # cannot use sub! because value is fozen
      # redact non-empty string
      if v and not v.empty?
        v = '<redacted>'
      end
  end
  print "#{k} #{v}\n"
end

# Optional extra info (from the main script only)
query = ENV['QUERY_STRING']
if query and not query.empty? and ENV['SCRIPT_URL'] == '/test.cgi'
    print "\n"
    system('which','-a','ruby')
    system('ruby','-v')
    wait=query.match(/^sleep=(\d+)$/)[1].to_i rescue 0
    if wait > 0
      print "\nWaiting #{wait} seconds ..."
      STDOUT.flush
      sleep wait
      print " done waiting\n"
    end
end
