##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

#!/usr/bin/env ruby
# Pony poop: utilities for analyzing data from Apache Ponymail APIs 
# - Analyze stats.lua JSON output for subject/author analysis
# - Analyze mbox.lua mbox files for author/list/lines written analysis
# 
# See also: https://ponymail.incubator.apache.org/docs/api
# See also: https://lists.apache.org/ngrams.html
require 'json'
require 'csv'
require 'net/http'
require 'cgi'
require 'optparse'
require_relative 'ponyapi'

# TODO: Fixup CSV output format to be more flexible, and/or add charting automatically
CSV_COLS = %w( Date TotalEmails TotalInteresting TotalThreads Missing Feedback Notice Report Resolution SVNAgenda SVNICLAs Person1 Emails1 Person2 Emails2 Person3 Emails3 Person4 Emails4 Person5 Emails5 )
BOARD_REGEX = { # Non-interesting email subjects from board # TODO add features for other lists
  missing: /\AMissing\s\S+\sBoard/,
  feedback: /\ABoard\sfeedback\son\s20/,
  notice: /\A\[NOTICE\]/i,
  report: /\A\[REPORT\]/i,
  resolution: /\A\[RESOLUTION\]/i,
  svn_agenda: %r{\Aboard: r\d{4,8} - /foundation/board/},
  svn_iclas: %r{\Aboard: r\d{4,8} - /foundation/officers/iclas.txt}
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
def analyze_stats(fname, results, subject_regex, errors)
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
      subjects = []
      results.last[:date] = f.chomp('.json')
      results.last[:email] = jzon['emails'].size
      results.last[:interesting] = results.last[:email]
      results.last[:threads] = jzon['no_threads']
      subject_regex.each do |t, s|
        results.last[t] = jzon['emails'].select{ |email| email['subject'] =~ s }.size
        results.last[:interesting] -= results.last[t] if subject_regex.keys.include? t 
      end
      # TODO: there's a more rubyish way to combine these loops
      subject_regex.each do |t, s|
        jzon['emails'].reject!{ |email| email['subject'] =~ s }
      end
      jzon['emails'].each do |email|
        subjects << email['subject']
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
      return subjects
    rescue Exception => e
      errors << "Bogosity! analyzing #{f} raised #{e.message[0..255]}"
      errors << "\t#{e.backtrace.join("\n\t")}"
    end
  end
end

# Analyze a set of local .json files downloaded from lists.a.o
def run_analyze_stats(dir, list, subject_regex)
  results = []
  errors = []
  subjects = []
  output = File.join("#{dir}", "output-#{list}")
  Dir[File.join("#{dir}", "#{list}*.json")].each do |fname|
    subjects = analyze_stats(fname, results, subject_regex, errors)
    if subjects
      responses = subjects.select {|subj| subj =~ /Re:/i }.size
      File.open("#{fname.chomp('.json')}.txt", "w") do |f|
        f.puts "COUNTS - Replies:#{responses}, New Messages:#{subjects.size - responses}"
        subjects.sort.each do |s|
          f.puts s.delete("\n")
        end
      end
    end
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
# Check options and call needed methods
# TODO: Simplify and allow both:
# - Downloading either stats or mbox
# - Analyzing either stats or mbox
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
    
    opts.on('-cCOOKIE', '--cookie COOKIE', 'For private lists REQUIRED, your ponymail logged-in cookie value') do |c|
      options[:cookie] = c
    end
    opts.on('-sSUBDOMAIN', '--subdomain SUBDOMAIN', 'Root @ subdomain .apache.org (only if project list; hadoop or community or...) to download stats archive from') do |s|
      options[:subdomain] = s.chomp('@.')
    end
    
    opts.on('-p', '--pull', 'Pull down stats JSON files into -d dir (otherwise, default analyzes existing stats JSON in dir)') do |p|
      options[:pull] = true
    end
    opts.on('-m', '--mbox', 'Pull down mbox files into -d dir') do |p|
      options[:mbox] = true
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
  months = %w( 1 2 3 4 5 6 7 8 9 10 11 12 )
  years = %w( 2010 2011 2012 2013 2014 2015 2016 2017 )
  options = optparse
  options[:list] ||= 'board'
  if options[:pull]
    puts "BEGIN: Pulling down stats JSONs in #{options[:dir]} of list: #{options[:list]}@#{options[:subdomain]}"
    PonyAPI::get_pony_stats_many options[:dir], options[:list], options[:subdomain], years, months, options[:cookie]
  elsif options[:mbox]
    puts "BEGIN: Pulling down mboxes in #{options[:dir]} of list: #{options[:list]}@#{options[:subdomain]}"
    PonyAPI::get_pony_mbox_many options[:dir], options[:list], options[:subdomain], years, months, options[:cookie]
  else
    puts "BEGIN: Analyzing local JSONs in #{options[:dir]} of list: #{options[:list]}"
    run_analyze_stats options[:dir], options[:list], BOARD_REGEX
  end
  puts "END: Thanks for running ponypoop - see results in #{options[:dir]}"
end

