#!/usr/bin/env ruby

print "Content-type: text/plain; charset=UTF-8\r\n\r\n"

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
  system(*cmd) or puts 'failed'
end

if ENV['SCRIPT_URL'] == '/members/test.cgi'
  print "\n"
  begin
    $LOAD_PATH.unshift '/srv/whimsy/lib'
    require 'whimsy/asf'
    puts "LDAP.hosts:"
    puts ASF::LDAP.hosts
    puts "LDAP.rwhosts:"
    puts ASF::LDAP.rwhosts
  rescue Exception => e
    p e
  end
end

# Optional extra info (from the main script only)
query = ENV['QUERY_STRING'] || ARGV[0]
if query and not query.empty? and ENV['SCRIPT_URL'] == '/test.cgi'
    print "\n"
    puts_system('id')
    puts_system('whoami')
    puts_system('which', '-a', 'svn')
    puts_system('svn', '--version')
    puts_system('which', '-a', 'git')
    puts_system('git', '--version')
    puts_system('which', '-a', 'svnmucc')
    puts_system('svnmucc', '--version')
    puts_system('which', '-a', 'ruby')
    puts_system('which', '-a', 'ruby2.3.0')
    puts_system('ruby', '-v')
    puts_system('gem', 'env')
    puts_system('which', '-a',  'gem')
    puts_system('PATH=/usr/local/bin:$PATH which -a gem')
    puts_system('service', 'puppet', 'status')
    puts_system('git', '-C', '/srv/whimsy', 'show', '--format="%h,  %ci %cr"', '-s', 'HEAD')
    puts_system('git', '-C', '/srv/whimsy', 'ls-remote', 'origin', 'master')
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
