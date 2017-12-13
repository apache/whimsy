#!/usr/bin/env ruby
<<~HEREDOC
Pony down: utilities for downloading Ponymail APIs (stats.lua or mbox.lua)
See also: https://ponymail.incubator.apache.org/docs/api
HEREDOC
require 'json'
require 'csv'
require 'net/http'
require 'cgi'

# Utilities for downloading from Ponymail APIs
module PonyAPI
  PONYHOST = ENV['PONYHOST'] || 'https://lists.apache.org/'
  PONYSTATS = PONYHOST + 'api/stats.lua?list=' # board&domain=apache.org&d=2017-04 becomes board-apache-org-201704-stats.json
  PONYMBOX  = PONYHOST + 'api/mbox.lua?list=' # board@apache.org&date=2016-06 becomes board-apache-org-201707.mbox
  PONYPREFS = PONYHOST + 'api/preferences.lua' # => preferences.json
  
  extend self

  # Get summary of all mailing lists by domain
  # Must supply cookie = 'ponymail-logged-in-cookie' to show private lists
  # if cookie == 'prompt' and the script is run interactively then
  # you will be prompted to enter the cookie value
  # The method writes the file 'lists.json' if dir != nil
  # it returns the data as a hash
  def get_pony_lists(dir, cookie=nil, sort_list=false)
    jzon = get_pony_prefs(nil, cookie)
    lists = jzon['lists']
    if lists
      if dir
        # no real point sorting unless writing the file
        lists = Hash[lists.sort] if sort_list
        File.open(File.join("#{dir}", 'lists.json'), "w") do |f|
          begin
            f.puts JSON.pretty_generate(lists)
          rescue JSON::GeneratorError
            puts "WARN:get_pony_lists() threw JSON::GeneratorError, continuing without pretty"
            f.puts lists
          end    
        end
      end
    end
    lists
  end

  # Get preferences including a summary of all mailing lists by domain
  # Must supply cookie = 'ponymail-logged-in-cookie' to show private lists
  # if cookie == 'prompt' and the script is run interactively then
  # you will be prompted to enter the cookie value
  # The method writes the file 'preferences.json' if dir != nil
  # it returns the data as a hash
  def get_pony_prefs(dir, cookie=nil, sort_list=false)
    cookie=get_cookie() if cookie == 'prompt'
    uri, request, response = fetch_pony(PONYPREFS, cookie)
    jzon = {}
    if response.code == '200' then
      jzon = JSON.parse(response.body)
      if dir
        # no real point sorting unless writing the file
        jzon['lists'] = Hash[jzon['lists'].sort] if sort_list && jzon['lists']
        File.open(File.join("#{dir}", 'preferences.json'), "w") do |f|
          begin
            f.puts JSON.pretty_generate(jzon)
          rescue JSON::GeneratorError
            puts "WARN:get_pony_prefs(#{uri.request_uri}) threw JSON::GeneratorError, continuing without pretty"
            f.puts jzon
          end    
        end
      end
    else
      puts "ERROR:get_pony_prefs(#{uri.request_uri}) returned code #{response.code.inspect}"
    end
    if cookie
      unless jzon['login'] && jzon['login']['credentials']
        puts "WARN:get_pony_prefs(#{uri.request_uri}) failed cookie test"
      end
    end
    jzon
  end

  # Download one month of stats as a JSON
  # Must supply cookie = 'ponymail-logged-in-cookie' if a private list
  def get_pony_stats(dir, list, subdomain, year, month, cookie)
    if subdomain.nil? || subdomain == ''
      getlist = "#{list}&domain=apache.org"
      fname = "#{list}-apache-org-%04d%02d-stats.json" % [year, month]
    else
      getlist = "#{list}&domain=#{subdomain}.apache.org"
      fname = "#{list}-#{subdomain}-apache-org-%04d%02d-stats.json" % [year, month]
    end
    uri, request, response = fetch_pony("#{PONYSTATS}#{getlist}&d=#{year}-#{month}", cookie)
    if response.code == '200' then
      File.open(File.join("#{dir}", "#{fname}"), "w") do |f|
        jzon = JSON.parse(response.body)
        begin
          f.puts JSON.pretty_generate(jzon)
        rescue JSON::GeneratorError
          puts "WARN:get_pony_stats(#{uri.request_uri}) threw JSON::GeneratorError, continuing without pretty"
          f.puts jzon
        end    
      end
    else
      puts "ERROR:get_pony_stats(#{uri.request_uri}) returned code #{response.code.inspect}"
    end
  end
  
  # Get multiple years/months of public stats as json
  def get_pony_stats_many(dir, list, subdomain, years, months, cookie)
    years.each do |y|
      months.each do |m|
        get_pony_stats dir, list, subdomain, y, m, cookie
      end
    end
  end
  
  # Download one month as mbox
  # Caveats: uses response's encoding; overwrites existing .json file
  # Must supply cookie = 'ponymail-logged-in-cookie' if a private list
  def get_pony_mbox(dir, list, subdomain, year, month, cookie)
    if subdomain.nil? || subdomain == ''
      getlist = "#{list}@apache.org"
      fname = "#{list}-apache-org-%04d%02d.mbox" % [year, month]
    else
      getlist = "#{list}@#{subdomain}.apache.org"
      fname = "#{list}-#{subdomain}-apache-org-%04d%02d.mbox" % [year, month]
    end
    uri, request, response = fetch_pony("#{PONYMBOX}#{getlist}&date=#{year}-#{month}", cookie)
    if response.code == '200'
      File.open(File.join("#{dir}", "#{fname}"), "w:#{response.body.encoding}") do |f|
        f.puts response.body
      end
    else
      puts "ERROR:get_public_mbox(#{uri}) returned code #{response.code.inspect}"
    end
  end
  
  # Get multiple years/months of mboxes
  def get_pony_mbox_many(dir, list, subdomain, years, months, cookie)
    years.each do |y|
      months.each do |m|
        get_pony_mbox dir, list, subdomain, y, m, cookie
      end
      sleep(1) # Be nice to the server; mboxes take effort
    end
  end

  private

  def get_cookie()
    unless $stdin.isatty
      puts "WARN:Input is not a tty; cannot prompt for a cookie"
      return nil
    end
    require 'io/console'
    $stdin.getpass('Please provide the login cookie: ')
  end

  # Fetch a Ponymail API, with optional logged-in cookie
  def fetch_pony(uri, cookie)
    uri = URI.parse(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |https|
      request = Net::HTTP::Get.new(uri.request_uri)
      request['Cookie'] = "ponymail=#{cookie}" if cookie != ''
      response = https.request(request)
      if response.code =~ /^3\d\d/
        fetch_pony response['location'], cookie
      else
        return uri, request, response
      end
    end
  end

end

if __FILE__ == $0
  method = ARGV.shift
  if method == '-v'
    verbose = true
    method = ARGV.shift
  else
    verbose = false
  end
  if method
    meth = PonyAPI.method(method)
    # process args to allow use of nil, true, false
    args = ARGV.map do |arg|
      case arg
      when 'nil'
        nil
      when 'true'
        true
      when 'false'
        false
      else
        arg
      end
    end
    $stderr.puts "Calling #{method}() using #{args.inspect}"
    res = meth.call(*args)
    puts res.inspect if verbose
  end
#  PonyAPI.get_pony_mbox('.', 'dev', 'whimsical', 2017, 01, nil)
#  PonyAPI.get_pony_stats('.', 'dev', 'whimsical', 2017, 01, nil)
#  puts PonyAPI.get_pony_prefs(nil, nil, true)['login'].inspect
#  puts PonyAPI.get_pony_lists(nil,nil,true).keys.length
end
