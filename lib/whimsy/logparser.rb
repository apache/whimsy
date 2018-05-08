#!/usr/bin/env ruby
# Gather simple statistics from whimsy server logs
# TODO security check ASF::Auth.decode before reading log files
require 'whimsy/asf'
require 'json'
require 'stringio'
require 'zlib'

# Utility methods to turn server logs into hashes of interesting data
module LogParser
  extend self
  # Hardcoded from https://github.com/apache/infrastructure-puppet/blob/deployment/modules/whimsy_server/manifests/init.pp#L200
  ERROR_LOG_DIR = '/srv/whimsy/www/members/log'
  
  # Constants and ignored regex for whimsy_access logs
  WHIMSY_APPS = %w(status roster board public secretary)
  RUSER = 'remote_user'
  REFERER = 'referer'
  REMAINDER = 'remainder'
  HITTOTAL = 'total'
  URIHIT = 'uri'
  IGNORED_URIS = [ 
    /\A\/whimsy.svg/, 
    /\A\/favicon.ico/, 
    /\A\/robots.txt/, 
    /\A\/assets/, 
    /\A\/fonts/,
    /\A\/icons/,
    /\.js\z/,
    /\.css\z/,
    /\.action\z/,
    /\.zip\z/, # Below here are all from site scanners
    /\..?ar\z/,
    /\.tar\..{1}z.?\z/,
    /\.bak\z/,
    /\.sql\z/,
    /\.7z\z/,
    /\.asp\.?\z/i,
    /\.txt\z/,
    /\.php\z/,
    /\.woff2/
  ]
  
  # Related to timestamps in error log output
  TRUNCATE = 6 # Ensure consistency in keys
  TIME_OFFSET = 10000000.0 # Offset milliseconds slightly for array entries
  # Ignore error lines from other tools with long tracebacks
  IGNORE_TRACEBACKS = ["rack.rb", "asf/themes", "phusion_passenger"]
  
  # Read a text or .gz file
  # @param f filename: .log or .log.gz
  # @return File.read(f)
  def read_logz(f)
    if f.end_with? '.gz'
      reader = Zlib::GzipReader.open(f)
      logfile = reader.read
      reader.close
      stream.close rescue nil
    else
      logfile = File.read(f)
    end
    return logfile
  end
  
  # Parse whimsy_access and return interesting entries
  # @param f filename of whimsy_access.log or .gz
  # @return array of reduced, scrubbed entries as hashes
  def parse_whimsy_access(f)
    access = read_logz(f).scan(/<%JSON:httpd_access%> (\{.*\})/).flatten
    logs = JSON.parse('[' + access.join(',') + ']').reject { |i| 
      (i['useragent'] =~ /Ping My Box/) || (i['uri'] =~ Regexp.union(IGNORED_URIS)) || (i['status'] == 304) 
    }
    logs.each do |i|
      %w(geo_country geo_long geo_lat geo_coords geo_city geo_combo duration request bytes vhost document request_method clientip query_string).each do |g|
        i.delete(g)
      end
    end
    return logs
  end
  
  # Collate/partition whimsy_access entries by app areas
  # @param logs full set of items to scan
  # @return apps - WHIMSY_APPS categorized, with REMAINDER entry all others
  def collate_whimsy_access(logs)
    remainder = logs
    apps = {}
    WHIMSY_APPS.each do |a|
      apps[a] = Hash.new{|h,k| h[k] = [] }
      apps[a][RUSER] = Hash.new{|h,k| h[k] = 0 }
      apps[a][REFERER] = Hash.new{|h,k| h[k] = 0 }
      apps[a][URIHIT] = Hash.new{|h,k| h[k] = 0 }
    end
    apps.each do |app, data|
      items, remainder = remainder.partition{ |l| l['uri'] =~ /\A\/#{app}/ }
      items.each do |l|
        data[RUSER][l[RUSER]] += 1
        data[REFERER][l[REFERER]] += 1
        data[URIHIT][l[URIHIT]] += 1
      end
    end
    apps[REMAINDER] = Hash.new{|h,k| h[k] = [] }
    apps[REMAINDER][RUSER] = Hash.new{|h,k| h[k] = 0 }
    apps[REMAINDER][REFERER] = Hash.new{|h,k| h[k] = 0 }
    apps[REMAINDER][URIHIT] = Hash.new{|h,k| h[k] = 0 }
    apps[REMAINDER]['useragent'] = Hash.new{|h,k| h[k] = 0 }
    remainder.each do |l|
      apps[REMAINDER][RUSER][l[RUSER]] += 1
      apps[REMAINDER][REFERER][l[REFERER]] += 1
      apps[REMAINDER][URIHIT][l[URIHIT]] += 1
      apps[REMAINDER]['useragent'][l['useragent']] += 1
    end
    return apps
  end
  
  # Get a simplistic hash report of access entries
  # @param f filepath to whimsy_access.log
  # @return app_report, misses_data
  def get_access_reports(f = File.join(ERROR_LOG_DIR, 'whimsy_access.log'))
    access = parse_whimsy_access(f)
    hits, miss = access.partition{ |l| l['status'] == 200 }
    apps = collate_whimsy_access(hits)
    return apps, miss
  end
  
  # Parse error.log and return interesting entries
  # @param f filename of error.log or .gz
  # @param logs hash to append to (created if nil) 
  # @return hash of string|array of interesting entries
  #   "timestamp" => "Passenger restarts and messages", 
  #   "timestamp" => ['_ERROR msg', '_WARN msg'... ]
  def parse_error_log(f, logs = {})
    last_time = 'uninitialized_time' # Cheap marker
    ignored = Regexp.union(IGNORE_TRACEBACKS)
    read_logz(f).lines.each do |l|
      begin
        # Emit each interesting item in order we read it 
        #   Include good-enough timestamping, even for un-timestamped items
        # (Date.today.to_time + 4/100000.0).iso8601(TRUNCATE)
        if l =~ /\[ . (.{24}) .+\]: (.+)/
          last_time = $1
          capture = $2
          if capture =~ /Passenger/
            logs[DateTime.parse(last_time).iso8601(TRUNCATE)] = capture
          end
        elsif (l =~ /(_ERROR|_WARN  (.+)whimsy)/) && !(l =~ ignored)
          # Offset our time so it doesn't overwrite any Passenger entries
          (logs[(DateTime.parse(last_time) + 1/TIME_OFFSET).iso8601(TRUNCATE)] ||= []) << l
        end
      rescue StandardError => e
        puts e
      end
    end
    return logs
  end
  
  # Parse error.log* files in dir and return interesting entries
  # @param d directory to scan for error.log*
  # @return hash of arrays of interesting entries
  def parse_error_logs(d = ERROR_LOG_DIR, logs = {})
    Dir[File.join(d, 'error.lo*')].each do |f|
      parse_error_log(f, logs)
    end
    return logs
  end
  
  # Parse whimsy_error.log and return interesting entries
  # @param f filename of error.log or .gz
  # @return hash of string of interesting entries
  #   "timestamp" => "AH01215: undefined method `map' for #<String:0x0000000240e1e0> (NoMethodError): /x1/srv/whimsy/www/status/errors.cgi"
  def parse_whimsy_error(f, logs = {})
    r = Regexp.new('\[(?<errdate>[^\]]*)\] \[cgi:error\] (\[([^\]]*)\] ){2}(?<errline>.+)')
    ignored = Regexp.union(IGNORE_TRACEBACKS)
    read_logz(f).lines.each do |l|
      if (m = r.match(l))
        if !(ignored =~ m[2])
          begin
            logs[DateTime.parse(m[1]).iso8601(6)] = m[2]
          rescue StandardError
            # Fallback to merely using the string representation
            logs[m[1]] = m[2]
          end
        end
      end
    end
    return logs
  end
  
  # Parse whimsy_error.log* files in dir and return interesting entries
  # @param d directory to scan for whimsy_error.log*
  # @return hash of arrays of interesting entries
  def parse_whimsy_errors(d = ERROR_LOG_DIR, logs = {})
    Dir[File.join(d, 'whimsy_error.lo*')].each do |f|
      parse_whimsy_error(f, logs)
    end
    return logs
  end
  
  # Get a list of all current|available error logs interesting entries
  # @param d directory to scan for *error.log*
  # @return hash of arrays of interesting entries
  def get_errors(d = ERROR_LOG_DIR, current = true)
    if current
      logs = LogParser.parse_whimsy_error(File.join(d, 'whimsy_error.log'))
      LogParser.parse_error_log(File.join(d, 'error.log'), logs)
    else
      logs = LogParser.parse_whimsy_errors(d)
      LogParser.parse_error_logs(d, logs)
    end
    return logs.sort.to_h # Sort by time order
  end
end

