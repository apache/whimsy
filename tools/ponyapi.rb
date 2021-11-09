#!/usr/bin/env ruby

# PonyAPI: utilities for downloading Ponymail APIs (stats.lua or mbox.lua)
# See also: https://ponymail.incubator.apache.org/docs/api

require 'json'
require 'csv'
require 'net/http'
require 'cgi'

# Utilities for downloading from Ponymail APIs
module PonyAPI
  PONYHOST = ENV['PONYHOST'] || 'https://lists.apache.org/'
  PONYSTATS = PONYHOST + 'api/stats.lua?list=%{list}&domain=%{domain}&d=%{year}-%{month}' # board&domain=apache.org&d=2017-04 becomes board-apache-org-201704-stats.json
  STATSMBOX = "%{list}-%{domNoDot}-%<year>.04d%<month>.02d-stats.json" # used to generate output file name
  SUMMARYJSON = "%{list}-%{domNoDot}-%<year>.04d%<month>.02d-summary.json" # used to generate output file name
  PONYMBOX  = PONYHOST + 'api/mbox.lua?list=%{list}@%{domain}&date=%{year}-%{month}' # board@apache.org&date=2016-06 becomes board-apache-org-201707.mbox
  FILEMBOX  = "%{list}-%{domNoDot}-%<year>.04d%<month>.02d.mbox" # used to generate output file name
  PONYPREFS = PONYHOST + 'api/preferences.lua' # => preferences.json

  extend self

  # Get summary of all mailing lists by domain
  # Must supply cookie = 'ponymail-logged-in-cookie' to show private lists
  # if cookie == 'prompt' and the script is run interactively then
  # you will be prompted to enter the cookie value
  # The method writes the file 'lists.json' if dir != nil
  # it returns the data as a hash
  def get_pony_lists(dir=nil, cookie=nil, sort_list=false, recurse_sort=false)
    cookie=get_cookie() if cookie == 'prompt'
    jzon = get_pony_prefs(nil, cookie)
    lists = jzon['lists']
    if lists
      if dir
        # no real point sorting unless writing the file
        if sort_list
          if recurse_sort
            lists.each do |k, v|
              lists[k] = Hash[v.sort]
            end
          end
         lists = Hash[lists.sort]
        end
        openfile(dir, 'lists.json') do |f|
          begin
            f.puts JSON.pretty_generate(lists)
          rescue JSON::GeneratorError => e
            puts "WARN:get_pony_lists() #{e.message} #{e.backtrace[0]}, continuing without pretty"
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
  def get_pony_prefs(dir=nil, cookie=nil, sort_list=false)
    cookie=get_cookie() if cookie == 'prompt'
    uri, _request, response = fetch_pony(PONYPREFS, cookie)
    jzon = {}
    if response.code == '200' then
      jzon = JSON.parse(response.body)
      if dir
        # no real point sorting unless writing the file
        jzon['lists'] = Hash[jzon['lists'].sort] if sort_list && jzon['lists']
        openfile(dir, 'preferences.json') do |f|
          begin
            f.puts JSON.pretty_generate(jzon)
          rescue JSON::GeneratorError
            puts "WARN:get_pony_prefs(#{uri.request_uri}) #{e.message} #{e.backtrace[0]}, continuing without pretty"
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
  def get_pony_stats(dir, list, subdomain, year, month, cookie=nil, sort_list=false, opts={})
    cookie = get_cookie() if cookie == 'prompt'
    args = make_args(list, subdomain, year, month)
    url = PONYSTATS % args
    url += '&quick' if opts[:quick]
    url += '&emailsOnly' if opts[:emailsOnly]
    uri, _request, response = fetch_pony(url, cookie)
    if response.code == '200' then
      return JSON.parse(response.body), args if dir.nil?
      openfile(dir, STATSMBOX % args) do |f|
        begin
          jzon = JSON.parse(response.body)
          jzon = Hash[jzon.sort] if sort_list
          f.puts JSON.pretty_generate(jzon)
        rescue JSON::JSONError
          begin
            # If JSON threw error, try again forcing to UTF-8 (may lose data)
            jzon = JSON.parse(response.body.encode('UTF-8', :invalid => :replace, :undef => :replace))
            jzon = Hash[jzon.sort] if sort_list
            f.puts JSON.fast_generate(jzon, {:max_nesting => false, :indent => ' '})
          rescue JSON::JSONError => e
            puts "WARN:get_pony_stats(#{uri.request_uri}) #{e.message} #{e.backtrace[0]}, continuing without pretty"
            f.puts jzon
          end
        end
      end
    else
      puts "ERROR:get_pony_stats(#{uri.request_uri}) returned code #{response.code.inspect}"
    end
  end

  # Get multiple years/months of public stats as json
  def get_pony_stats_many(dir, list, subdomain, years, months, cookie=nil)
    cookie=get_cookie() if cookie == 'prompt'
    years.each do |y|
      months.each do |m|
        get_pony_stats dir, list, subdomain, y, m, cookie
      end
    end
  end

  # get summary stats; exclude details
  def get_pony_summary(dir, list, subdomain, year, month, cookie=nil, sort_list=false)
    res, args = get_pony_stats(nil, list, subdomain, year, month, cookie, sort_list)
    return nil unless res
    jzon = {}
    %w(list domain name firstYear firstMonth lastYear lastMonth numparts hits no_threads unixtime max).each { |k| jzon[k] = res[k]}
    %w(participants emails thread_struct).each { |k| jzon["#{k}.size"] = res[k].size}
    if dir
      openfile(dir, SUMMARYJSON % args) do |f|
        jzon = Hash[jzon.sort] if sort_list
        f.puts JSON.pretty_generate(jzon)
      end
    end
    jzon
  end

  # Download one month as mbox
  # Caveats: uses response's encoding; overwrites existing .json file
  # Must supply cookie = 'ponymail-logged-in-cookie' if a private list
  def get_pony_mbox(dir, list, subdomain, year, month, cookie=nil)
    cookie = get_cookie() if cookie == 'prompt'
    args = make_args(list, subdomain, year, month)
    uri, _request, response = fetch_pony(PONYMBOX % args, cookie)
    if response.code == '200'
      openfile(dir, FILEMBOX % args, "w:#{response.body.encoding}") do |f|
        f.puts response.body
      end
    else
      puts "ERROR:get_public_mbox(#{uri}) returned code #{response.code.inspect}"
    end
  end

  # Get multiple years/months of mboxes
  def get_pony_mbox_many(dir, list, subdomain, years, months, cookie=nil)
    cookie=get_cookie() if cookie == 'prompt'
    years.each do |y|
      months.each do |m|
        get_pony_mbox dir, list, subdomain, y, m, cookie
      end
      sleep(1) # Be nice to the server; mboxes take effort
    end
  end

  private

  # Open the output file
  # if dir == '-' then use stdout
  # if dir ends with '.json' then treat it as the full file name
  def openfile(dir,file, mode='w')
    if dir == '-'
      yield $stdout
    elsif dir.end_with? '.json'
      yield File.open(dir, mode)
    else
      yield File.open(File.join(dir, file), mode)
    end
  end

  # create an argument list suitable for string formatting
  def make_args(list, subdomain, year, month)
    if subdomain.nil? || subdomain == ''
      domain = 'apache.org'
    elsif subdomain.include? '.' # assume full host provided
      domain = subdomain
      subdomain = subdomain.sub(%r{\..*},'') # can't use sub! with CLI arg
    elsif subdomain == '*' # allow wildcard domain
      domain = subdomain
    else
      domain = subdomain + '.apache.org'
    end
    {list: list, subdomain: subdomain, domain: domain, domNoDot: domain.gsub('.','-'),year: year, month: month}
  end

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
      when %r{\A{[":1a-zA-Z,]+}\z} # e.g. '{"quick":1,"emailsOnly":1}'
        JSON.parse(arg, symbolize_names: true)
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
