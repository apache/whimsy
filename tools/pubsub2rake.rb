#!/usr/bin/env ruby

$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'net/http'
require 'json'
require 'thread'
require 'whimsy/asf/config'
require 'whimsy/asf/svn'

class PubSub

  require 'fileutils'
  ALIVE = "/tmp/#{File.basename(__FILE__)}.alive" # TESTING ONLY

  @restartable = false
  @updated = false
  def self.listen(url, creds, options={})
    debug = options[:debug]
    mtime = File.mtime(__FILE__)
    done = false
    ps_thread = Thread.new do
      begin
        uri = URI.parse(url)
        Net::HTTP.start(uri.host, uri.port,
          open_timeout: 20, read_timeout: 20, ssl_timeout: 20,
          use_ssl: url.match(/^https:/) ? true : false) do |http|
          request = Net::HTTP::Get.new uri.request_uri
          request.basic_auth *creds if creds
          http.request request do |response|
            body = ''
            response.read_body do |chunk|
              FileUtils.touch(ALIVE) # Temporary debug
              body += chunk
              # All chunks are terminated with \n. Since 2070 can split events into 64kb sub-chunks
              # we wait till we have gotten a newline, before trying to parse the JSON.
              if chunk.end_with? "\n"
                event = JSON.parse(body.chomp)
                body = ''
                if event['stillalive']  # pingback
                  @restartable = true
                  puts(event) if debug
                else
                  yield event
                  # code.call event
                end
              else
                puts("Partial chunk") if debug
              end
              unless mtime == File.mtime(__FILE__)
                puts "File updated" if debug
                @updated = true
                done = true
              end
              break if done
            end # reading chunks
            puts "Done reading chunks" if debug
            break if done
          end # read response
          puts "Done reading response" if debug
          break if done
        end # net start
        puts "Done with start" if debug
      rescue Errno::ECONNREFUSED => e
        @restartable = true
        STDERR.puts e.inspect
        sleep 3
      rescue Exception => e
        STDERR.puts e.inspect
        STDERR.puts e.backtrace
      end
      puts "Done with thread" if debug
    end # thread
    puts("Pubsub thread started ...")
    ps_thread.join
    puts("Pubsub thread finished ...")
    puts("Updated") if @updated
    if @restartable
      STDERR.puts 'restarting'
    
      # relaunch script after a one second delay
      sleep 1
      exec RbConfig.ruby, __FILE__, *ARGV
    end
  end
end

if $0 == __FILE__
  $stdout.sync = true

  pubsub_URL = ARGV.shift  || 'https://pubsub.apache.org:2070/svn'
  pubsub_FILE = ARGV.shift || File.join(Dir.home,'.pubsub')
  pubsub_CRED = File.read(pubsub_FILE).chomp.split(':') rescue nil

  WATCH=Hash.new{|h,k| h[k] = Array.new}
  # determine which paths were are interested in
  # depth: 'skip' == ignore completely
  # files: only need to update if path matches one of the files
  # depth: 'files' only need to update for top level files
  
  # The first segment of the url is the repo name, e.g. asf or infra
  # The second segment is the subdir within the repo.
  # The combination of the two are used for the pubsub path, for example:
  # asf/infrastructure/site/trunk/content/foundation/records/minutes
  # relates to pubsub_path: svn/asf/infrastructure

  def process(event)
    path = event['pubsub_path']
    if WATCH.include? path # WATCH auto-vivifies
      matches = Hash.new{|h,k| h[k] = Array.new} # key alias, value = array of matching files
      watching = WATCH[path]
      watching.each do |svn_prefix, svn_alias, files|
        changed = event['commit']['changed']
        changed.keys.each do |ck|
          if ck.start_with? svn_prefix # file matches target path
            if files && files.size > 0 # but does it match exactly?
              files.each do |file|
                if ck == File.join(svn_prefix, file)
                  matches[svn_alias] << ck
                  break # no point checking other files
                end
              end
            else 
              matches[svn_alias] << ck
            end
          end
        end
      end
      matches.each do |k,v|
        cmd = ['rake', "svn:update[#{k}]"]
        unless system(*cmd, {chdir: '/srv/whimsy'})
          puts "Error #{$?} processing #{cmd}"
        end
      end
    end # possible match
  end

  ASF::SVN.repo_entries(true).each do |name,desc|
    next if desc['depth'] == 'skip' # not needed
    url = desc['url']

    one,two,three=url.split('/',3)
    path_prefix = one == 'private' ? ['/private','svn'] : ['/svn'] 
    pubsub_key = [path_prefix,one,two,'commit'].join('/')
    svn_relpath = [two,three].join('/')
    WATCH[pubsub_key] << [svn_relpath, name, desc['files']]
  end

  if pubsub_URL == 'WATCH' # dump keys for use in constructing URL
    p WATCH.keys
    exit
  end

  if File.exist? pubsub_URL
    puts "** Unit testing **"
    open(pubsub_URL).each_line do |line|
      event = nil
      begin
      event = JSON.parse(line.chomp)
      rescue Exception => e
        p e
        puts line
      end
      process(event) unless event == nil || event['stillalive']
    end
  else
    PubSub.listen(pubsub_URL,pubsub_CRED) do | event |
      process(event)
    end
  end
end 