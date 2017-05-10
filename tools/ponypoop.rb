#!/usr/bin/env ruby
<<~HEREDOC
Pony poop: simple statistics for Apache Ponymail monthly archives
  - Methods to pull down stats.lua JSON structures of monthly archive reports
  - Medhods to analyze local .json structures with chartable stats 
   
   See also: https://ponymail.incubator.apache.org/docs/api
   See also: https://lists.apache.org/ngrams.html
HEREDOC
require 'json'
require 'csv'
require 'net/http'
require 'cgi'
require 'optparse'

PONYSTATS = 'https://lists.apache.org/api/stats.lua?list=' # board&domain=apache.org&d=2017-04 becomes board-apache-org-201704.json

# TODO: Fixup CSV output format to be more flexible, and/or add charting automatically
CSV_COLS = %w( Date TotalEmails TotalInteresting TotalThreads Missing Feedback Notice Report Resolution SVNAgenda SVNICLAs Person1 Emails1 Person2 Emails2 Person3 Emails3 Person4 Emails4 Person5 Emails5 )
BOARD_REGEX = { # Non-interesting email subjects from board
  missing: /\AMissing\s\S+\sBoard/,
  feedback: /\ABoard\sfeedback\son\s20/,
  notice: /\A\[NOTICE\]/i,
  report: /\A\[REPORT\]/i,
  resolution: /\A\[RESOLUTION\]/i,
  svn_agenda: %r{\Aboard: r\d{4,7} - /foundation/board/board_agenda_},
  svn_iclas: %r{\Aboard: r\d{4,7} - /foundation/officers/iclas.txt}
}

# ## ### #### ##### ######
# Analysis functions, scanning stats.lua output JSON
# Determine max, total thread depth (only within current data)
def analyze_threads(threads)
  # We are a hash that always includes a 'children' entry
  #  which is either a hash (empty) or an array of hashes
  # TODO This code doesn't actually get correct depths
  max = 1
  total = 1
  if threads['children'].is_a?(Array) then
    max += 1
    threads['children'].each do |thread|
      m, t = analyze_threads(thread)
      total += t
    end
    p "Hsh: #{threads.class} - #{threads.size} at #{threads['epoch']} #{max}/#{total}"
  end
  
  return max, total
end

# Analyze a local .json for interesting vs. not interesting board@ subjects
def analyze(fname, results, subject_regex, errors)
  begin
    f = File.basename(fname)
    begin
      jzon = JSON.parse(File.read(fname))
    rescue Exception => e
      errors << "Bogosity! parsing #{f} raised #{e.message[0..255]}"
      errors << "\t#{e.backtrace.join("\n\t")}"
      return
    end
    begin
      results << {}
      results.last[:date] = f.chomp('.json')
      results.last[:email] = jzon['emails'].size
      results.last[:interesting] = results.last[:email]
      results.last[:threads] = jzon['no_threads']
      subject_regex.each do |t, s|
        results.last[t] = jzon['emails'].select{ |email| email['subject'] =~ s }.size
        results.last[:interesting] -= results.last[t] if subject_regex.keys.include? t 
        # TODO: return a list of all subject lines that are interesting for human analysis
      end
      # max = 0
      # total = 0
      # jzon['thread_struct'].each do |thread|
      #   m, t = analyze_threads(thread)
      #   max = m if m > max
      #   total += t
      # end
      # puts "max/total #{max}/#{total}"
      # results.last[:maxdepth] = max
      # results.last[:avgdepth] = total / jzon['no_threads']
      ctr = 1
      jzon['participants'].each do |participant|
        unless participant['name'] =~ /@/ # Ignore SVN commit mails
          results.last["Person#{ctr}"] = participant['name']
          results.last["Emails#{ctr}"] = participant['count']
          ctr += 1
          break if ctr > 5
        end
      end
    rescue Exception => e
      errors << "Bogosity! analyzing #{f} raised #{e.message[0..255]}"
      errors << "\t#{e.backtrace.join("\n\t")}"
      return
    end
  end
end

# Analyze a set of local .json files downloaded from lists.a.o
def run_analyze(dir, list, subject_regex)
  results = []
  errors = []
  output = File.join("#{dir}", "output-#{list}")
  Dir[File.join("#{dir}", "#{list}*.json")].each do |fname|
    analyze(fname, results, subject_regex, errors)
  end
  CSV.open("#{output}.csv",'w', :write_headers=> true, :headers => CSV_COLS) do |csv|
    results.each do |r|
      csv << r.values
    end
  end
  if errors.size > 0 
    results << {}
    errors.each_with_index do |item, index|
      results.last["error#{index}"] = item
    end
  end
  File.open("#{output}.json", "w") do |f|
    f.puts JSON.pretty_generate(results)
  end
  
  results
end

# ## ### #### ##### ######
# Download functions: grab monthly stats.lua data as .jsons
# Grab monthly data from lists.a.o - for private lists
def get_private_from_archive(dir, list, years, months, cookie)
  cookieval = "ponymail=#{cookie}"
  years.each do |y|
    months.each do |m|
      uri = URI("#{PONYSTATS}#{list}&domain=apache-org&d=#{y}-#{m}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      request['Cookie'] = cookieval
      r = http.request(request)
      if r.code =~ /200/ then
        File.open(File.join("#{dir}", "#{list}-apache-org-#{y}#{m}.json"), "w") do |f|
          jzon = JSON.parse(r.body)
          begin
            f.puts JSON.pretty_generate(jzon)
          rescue JSON::GeneratorError
            puts "Bogosity: Generator error on #{r.code} for #{uri.request_uri}"
            f.puts jzon
          end    
        end
      else
        puts "Double Bogus! #{r.code} for #{uri.request_uri}"
      end
    end
  end
end

# ## ### #### ##### ######
# Grab monthly data from lists.a.o - only for public lists
# fetch uri, following redirects: tools/site-scan.rb
def fetch(uri)
  uri = URI.parse(uri)
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    if response.code =~ /^3\d\d/
      fetch response['location']
    else
      return uri, request, response
    end
  end
end

# Grab monthly data from lists.a.o - for public lists
def get_public_from_archive(dir, list, subdomain, year, month)
  uri, request, response = fetch("#{PONYSTATS}#{list}&domain=#{subdomain}.apache.org&d=#{year}-#{month}")
  pmails = JSON.parse(response.body)
  
  File.open(File.join("#{dir}", "#{list}-#{subdomain}-apache-org-#{year}-#{month}.json"), "w") do |f|
    f.puts JSON.pretty_generate(pmails)
  end  
end

def get_all_public(dir, list, subdomain, years, months)
  years.each do |y|
    months.each do |m|
      get_public_from_archive dir, list, subdomain, y, m
    end
  end
end

# ## ### #### ##### ######
# Check options and call needed methods
# TODO: this assumes you correctly use -c and -s
def optparse
  options = {}
  OptionParser.new do |opts|
    opts.on('-h') { puts opts; exit }
    
    opts.on(:REQUIRED, '-dDIRECTORY', '--directory DIRECTORY', 'Local directory to dump/find .json files (required)') do |d|
      if File.directory?(d)
        options[:dir] = d
      else
        raise ArgumentError, "-d #{d} is not a valid directory" 
      end
    end
    opts.on(:REQUIRED, '-lLISTNAME', '--list LISTNAME', 'Root listname to download stats archive from (required; board or trademarks or...)') do |l|
      options[:list] = l.chomp('@')
    end
    
    opts.on('-cCOOKIE', '--cookie COOKIE', 'For private lists, your ponymail logged-in cookie value') do |c|
      options[:cookie] = c
    end
    opts.on('-sSUBDOMAIN', '--list SUBDOMAIN', 'Root @ subdomain .apache.org (only if project list; hadoop or community or...) to download stats archive from') do |s|
      options[:subdomain] = s.chomp('@.')
    end
    
    opts.on('-p', '--pull', 'Pull down stats into -d dir (otherwise, analyzes existing stats in dir)') do |p|
      options[:pull] = true
    end
    
    begin
      opts.parse!
    rescue OptionParser::ParseError => e
      $stderr.puts e
      $stderr.puts "try -h for valid options, or see code"
      exit 1
    end
  end
  
  return options
end

# ## ### #### ##### ######
# Main method for command line use
if __FILE__ == $PROGRAM_NAME
  months = %w( 01 02 03 04 05 06 07 08 09 10 11 12 )
  years = %w( 2010 2011 2012 2013 2014 2015 2016 2017 )
  options = optparse
  options[:list] ||= 'board'
  if options[:pull]
    # TODO make months/years settable
    raise ArgumentError "Must have a -c COOKIE to -p pull private archives" unless options[:cookie]
    puts "BEGIN: Pulling down JSON to #{options[:dir]} of list: #{options[:list]} @ #{options[:subdomain]} "
    get_private_from_archive options[:dir], options[:list], years, months, options[:cookie]
  else
    puts "BEGIN: Analyzing local JSONs in #{options[:dir]} of list: #{options[:list]}"
    run_analyze options[:dir], options[:list], BOARD_REGEX
  end
  puts "END: Thanks for running ponypoop - see results in #{options[:dir]}"
end



