#!/usr/bin/env ruby
# Scan all /www scripts for WVisible PAGETITLE and categories
$LOAD_PATH.unshift File.realpath(File.expand_path('../../lib', __FILE__))
SCANDIR = "../www"
ISERR = '!'

# Return [PAGETITLE, [cat,egories] ] after WVisible; or same as !Bogosity error
def scanfile(f)
  begin
    File.open(f).each_line.map(&:chomp).each do |line|
      if line =~ /\APAGETITLE\s?=\s?"([^"]+)"\s?#\s?WVisible:(.*)/i then
        return [$1, $2.chomp.split(%r{[\s,]})]
      end
    end
    return nil
  rescue Exception => e
    return ["!Bogosity! #{e.message[0..255]}", "\t#{e.backtrace.join("\n\t")}"]
  end
end

# Return data only about WVisible cgis, plus any errors
def scandir(dir)
  links = {}
  Dir["#{dir}/**/*.cgi".untaint].each do |f|
    l = scanfile(f.untaint)
    links[f.sub(dir, '')] = l if l
  end
  return links
end
