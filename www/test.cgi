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

