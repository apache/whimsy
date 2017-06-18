#!/usr/bin/env ruby

print "Content-type: text/plain\r\n\r\n"

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

def puts_system(*cmd)
  puts ['$', cmd].join ' '
  system *cmd
end

# Optional extra info (from the main script only)
query = ENV['QUERY_STRING'] || ARGV[0]
if query and not query.empty? and ENV['SCRIPT_URL'] == '/test.cgi'
    print "\n"
    puts_system('which','-a','svn')
    puts_system('svn','--version')
    puts_system('which','-a','ruby')
    puts_system('which','-a','ruby2.3.0')
    puts_system('ruby','-v')
    puts_system('gem','env')
    puts_system('which','-a','gem')
    puts_system('PATH=/usr/local/bin:$PATH which -a gem')
    puts_system('service puppet status')
    puts_system('git ls-remote origin master')
    wait=query.match(/^sleep=(\d+)$/)[1].to_i rescue 0
    if wait > 0
      print "\nWaiting #{wait} seconds ..."
      STDOUT.flush
      sleep wait
      print " done waiting\n"
    end
    require 'socket'
    hostname = Socket.gethostname
    require 'resolv'
    master = nil
    current = nil
    Resolv::DNS.open do |rs|
      master = rs.getaddress("whimsy.apache.org")
      current = rs.getaddress(hostname) rescue nil
    end
    print "master: #{master} current: #{current}\n"
    if current == master
      print "This system is the Whimsy master\n"
    else
      print "This system is not the Whimsy master\n"
    end
    print "All done\n"
end
