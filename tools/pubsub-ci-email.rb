#!/usr/bin/env ruby

$LOAD_PATH.unshift '/srv/whimsy/lib'

# Script to detect changes to committee-info.txt and send emails to board and the PMC

require 'mail'
require 'net/http'
require 'json'
require 'whimsy/asf'
require 'whimsy/asf/json-utils'

def stamp(*s)
  "%s: %s" % [Time.now.gmtime.to_s, s.join(' ')]
end

class PubSub

  require 'fileutils'
  ALIVE = File.join("/tmp", "#{File.basename(__FILE__)}.alive") # TESTING ONLY

  @restartable = false
  @updated = false
  def self.listen(url, creds, options={})
    debug = options[:debug]
    mtime = File.mtime(__FILE__)
    FileUtils.touch(ALIVE) # Temporary debug - ensure exists
    done = false
    ps_thread = Thread.new do
      begin
        uri = URI.parse(url)
        Net::HTTP.start(uri.host, uri.port,
          open_timeout: 20, read_timeout: 20, ssl_timeout: 20,
          use_ssl: url.match(/^https:/) ? true : false) do |http|
          request = Net::HTTP::Get.new uri.request_uri
          request.basic_auth(*creds) if creds
          http.request request do |response|
            response.each_header do |h, v|
              puts stamp [h, v].inspect if h.start_with? 'x-' or h == 'server'
            end
            body = ''
            response.read_body do |chunk|
              # Long time no see?
              lasttime = File.mtime(ALIVE)
              diff = (Time.now - lasttime).to_i
              if diff > 60
                puts stamp 'HUNG?', diff, lasttime
              end
              FileUtils.touch(ALIVE) # Temporary debug
              body += chunk
              # All chunks are terminated with \n. Since 2070 can split events into 64kb sub-chunks
              # we wait till we have gotten a newline, before trying to parse the JSON.
              if chunk.end_with? "\n"
                event = JSON.parse(body.chomp)
                body = ''
                if event['stillalive'] # pingback
                  @restartable = true
                  puts stamp event if debug
                else
                  yield event # return the event to the caller
                end
              else
                puts stamp "Partial chunk" if debug
              end
              unless mtime == File.mtime(__FILE__)
                puts stamp "File updated" if debug
                @updated = true
                done = true
              end
              break if done
            end # reading chunks
            puts stamp "Done reading chunks" if debug
            break if done
          end # read response
          puts stamp "Done reading response" if debug
          break if done
        end # net start
        puts stamp "Done with start" if debug
      rescue Errno::ECONNREFUSED => e
        @restartable = true
        $stderr.puts stamp e.inspect
        sleep 3
      rescue StandardError => e
        $stderr.puts stamp e.inspect
        $stderr.puts stamp e.backtrace
      end
      puts stamp "Done with thread" if debug
    end # thread
    puts stamp "Pubsub thread started #{url} ..."
    ps_thread.join
    puts stamp "Pubsub thread finished %s..." % (@updated ? '(updated) ' : '')
    if @restartable and ! ARGV.include? '--prompt'
      $stderr.puts stamp 'restarting'

      # relaunch script after a one second delay
      sleep 1
      exec RbConfig.ruby, __FILE__, *ARGV
    end
  end
end

# =========================

PUBSUB_URL = 'https://pubsub.apache.org:2070/private/svn/private/committers/commit'

FILE='committee-info.txt'
SOURCE_URL='https://svn.apache.org/repos/private/committers/board/committee-info.txt'

# last seen revision of committee-info.txt
PREVIOUS_REVISION = '/srv/svn/committee-info_last_revision.txt'

TYPES = {
  'Added' => 'added to',
  'Dropped' => 'dropped from'
}

# fetch contents of a revision
def fetch_revision(rev)
  content, err = ASF::SVN.svn!('cat', SOURCE_URL, {revision: rev})
  content
end

def parse_content(content)
  non, off, all = ASF::Committee.parse_committee_info_nocache(content)
  com = (all - non - off).reject{|c| c.established.nil?} # allow for missing section 3
  com.map {|cttee|
      [cttee.name.gsub(/[^-\w]/, ''), {'roster' => cttee.roster.sort.to_h}]
  }.to_h
end

# Compare files. initial and current are arrays: [rev,commiter,date]
def do_diff(initiala, currenta)
  initial = initiala[0]
  current = currenta[0]
  puts "Comparing #{initial} with #{current}"
  before = parse_content(fetch_revision(initial))
  after = parse_content(fetch_revision(current))
  puts "No changes detected" if before == after
  ASFJSON.cmphash(before, after) do |bc, type, key, args|
    id = bc[1]
    next unless id
    cttee = ASF::Committee.find(id)
    mail_list = "private@#{cttee.mail_list}.apache.org"
    subject = "[TEST][NOTICE] #{args[:name]} (#{key}) #{TYPES[type] || type} #{cttee.display_name} in #{current}"
    to = "board@apache.org,#{mail_list}"
    body = <<~EOD
    This is a TEST email
    ====================
    To: board@apache.org,#{mail_list}
    
    Commit #{current} by #{currenta[1]} at #{currenta[2]}
    resulted in the following change:
    
    #{args[:name]} (#{key}) #{TYPES[type] || type} #{cttee.display_name} 
    Joining date: #{args[:date]}

    This is in comparison with the previous commit:
    #{initial} by #{initiala[1]} at #{initiala[2]}
  
    Generated by: #{__FILE__}
    EOD
    mail = Mail.new do
      from "notifications@whimsy.apache.org" # TODO is this correct?
      # to to # Intial testing, only use Bcc
      bcc 'notifications@whimsy.apache.org' # keep track of mails
      subject subject
      body body
    end
    mail.deliver!
  end
end

# Process trigger from pubsub
def handle_change(revision)
  puts stamp "handle_change in #{revision}"
  # get the last known revision
  begin
    previous_revision = File.read(PREVIOUS_REVISION).chomp
    puts "Detected last known revision '#{previous_revision}'"
    # get list of commmits from initial to current.
    # @return array of entries, each of which is an array of [commitid, committer, datestamp]
    out,_ = ASF::SVN.svn_commits!(SOURCE_URL, previous_revision, revision)
    puts "No changes found since then" if out.size <= 1
    # Get pairs of entries and calculate differences
    out.each_cons(2) do |before, after|
      do_diff(before, after)
      File.write(PREVIOUS_REVISION, after[0]) # done that one
    end
  rescue StandardError => e
    raise e
  end
end

def process(event)
  pubsub_path = event['pubsub_path']
  if event['commit']['changed'].include? "committers/board/#{FILE}"
    revision = event['commit']['id']
    committer = event['commit']['committer']
    log = event['commit']['log']
    puts stamp "Found change to #{FILE} in #{revision} by #{committer}: #{log}"
    handle_change(revision)
  end
end

if $0 == __FILE__
  $stdout.sync = true

  if ARGV.delete('--testchange')
    handle_change (ARGV.shift or raise "Need change id")
    exit
  end

  options = {}
  args = ARGV.dup # preserve ARGV for relaunch

  prompt = args.delete('--prompt') # 
  options[:debug] = args.delete('--debug')
  pubsub_URL = args[0]  || PUBSUB_URL
  pubsub_FILE = args[1] || File.join(Dir.home, '.pubsub')

  if prompt # debug
    require 'io/console'
    user ||= Etc.getlogin
    pubsub_CRED = [user, STDIN.getpass("Password for #{user}: ")]
  else
    pubsub_CRED = File.read(pubsub_FILE).chomp.split(':') or raise ArgumentError.new "Missing credentials"
  end

  puts stamp(pubsub_URL)
  PubSub.listen(pubsub_URL, pubsub_CRED, options) do |event|
    puts stamp event if options[:debug]
    process(event)
  end
end

__END__
Sample public commit
{
 "commit": {
  "changed": {
   "comdev/reporter.apache.org/trunk/data/history/projects.json": {
    "flags": "U  "
   }
  },
  "committer": "projects_role",
  "date": "2024-02-28 20:10:02 +0000 (Wed, 28 Feb 2024)",
  "format": 1,
  "id": 1916046,
  "log": "updating report releases data",
  "repository": "13f79535-47bb-0310-9956-ffa450edef68",
  "type": "svn"
 },
 "pubsub_cursor": "efde32f6-8e97-484d-a9d2-2a7eee88e4f3",
 "pubsub_path": "/svn/asf/comdev/commit",
 "pubsub_timestamp": 1709151002.6564121,
 "pubsub_topics": [
  "svn",
  "asf",
  "comdev",
  "commit"
 ]
}
