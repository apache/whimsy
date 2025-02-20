#!/usr/bin/env ruby

$LOAD_PATH.unshift '/srv/whimsy/lib'

# Script to detect changes to committee-info.txt and send emails to board and the PMC
# Only sends change emails if it is the active Whimsy (or a test node, which is expected to use a dummy smtpserver)

require 'mail'
require 'net/http'
require 'json'
require 'whimsy/asf'
require 'whimsy/asf/status'
require 'whimsy/asf/json-utils'

def stamp(*s)
  '%s: %s' % [Time.now.gmtime.to_s, s.join(' ')]
end

def mail_notify(subject, body=nil)
  mail = Mail.new do
    to 'notifications@whimsical.apache.org'
    from 'notifications@whimsical.apache.org'
    subject subject
    body body
  end
  if Status.active? or Status.testnode?
    mail.deliver!
  else
    puts stamp "Would have sent: #{mail}"
  end
end

class PubSub

  require 'fileutils'
  ALIVE = File.join('/tmp', "#{File.basename(__FILE__)}.alive") # TESTING ONLY

  @restartable = false
  @updated = false
  def self.listen(url, creds, options={})
    debug = options[:debug]
    mtime = File.mtime(__FILE__)
    FileUtils.touch(ALIVE) # Temporary debug - ensure exists
    done = false
    except = nil
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
                puts stamp 'Partial chunk' if debug
              end
              unless mtime == File.mtime(__FILE__)
                puts stamp 'File updated' if debug
                @updated = true
                done = true
              end
              break if done
            end # reading chunks
            puts stamp 'Done reading chunks' if debug
            break if done
          end # read response
          puts stamp 'Done reading response' if debug
          break if done
        end # net start
        puts stamp 'Done with start' if debug
      rescue Errno::ECONNREFUSED => e
        @restartable = true
        except = e
        puts stamp e.inspect
        sleep 3
      rescue StandardError => e
        except = e
        puts stamp e.inspect
        puts stamp e.backtrace
      end
      puts stamp 'Done with thread' if debug
    end # thread
    puts stamp "Pubsub thread started #{url} ..."
    ps_thread.join
    subject = 'Pubsub thread finished %s...' % (@updated ? '(code updated) ' : '')
    puts stamp subject
    mail_notify subject, <<~EOD
    Restartable: #{@restartable}
    Exception: #{except.inspect}
    EOD
    if @restartable and ! ARGV.include? '--prompt'
      puts stamp 'restarting'

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
# Try to guard against flooding mailing lists
MAX_COMMITS = 10 # Max commits allowed since previous revision
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

# Compare files. parameters are hashes {:revision, :author, :date}
def do_diff(initialhash, currenthash, triggerrev)
  initialrev = initialhash[:revision]
  # initialcommitter = initialhash[:author]
  # initialdate = initialhash[:date]
  currentrev = currenthash[:revision]
  currentcommitter = currenthash[:author]
  currentdate = currenthash[:date]
  commit_msg = currenthash[:msg]
  currentcommittername = ASF::Person.find(currentcommitter).public_name
  puts stamp "Comparing #{initialrev} with #{currentrev}"
  before = parse_content(fetch_revision(initialrev))
  after = parse_content(fetch_revision(currentrev))
  if before == after
    puts stamp 'No changes detected'
  else
    puts stamp 'Analysing changes'
  end
  #  N.B. before/after are hashes: committee_name => {roster hash}
  ASFJSON.cmphash(before, after) do |bc, type, key, args|
    # bc = breadcrumb, type = Added/Dropped, key = committeename, args = individual roster entry
    pmcid = bc[1]
    unless pmcid
      puts stamp "SKIPPING: #{[bc, type, key, args].inspect} - not a PMC"
      next
    end
    unless TYPES.include? type # Don't need to handle changes to entries
      puts stamp "SKIPPING: #{[bc, type, key, args].inspect} - not a roster change"
      next
    end
    puts stamp "INFO: #{[bc, type, key, args].inspect}"
    cttee = ASF::Committee.find(pmcid)
    ctteename = cttee.display_name
    userid = key
    username = args[:name]
    joindate = args[:date]
    mail_list = cttee.private_mail_list
    change_text = TYPES[type] || type # 'added to|dropped from'
    subject = "[NOTICE] #{username} (#{userid}) #{change_text} #{ctteename} in #{currentrev}"
    body = <<~EOD
    On #{currentdate} #{username} (#{userid}) was #{change_text} the
    #{ctteename} PMC by #{currentcommittername} (#{currentcommitter}).

    The commit message was:
       #{commit_msg}

    Links for convenience:
    https://svn.apache.org/repos/private/committers/board/committee-info.txt?p=#{currentrev}
    https://lists.apache.org/list?#{mail_list}
    https://whimsy.apache.org/roster/committee/#{cttee.name}

    This is an automated email generated by Whimsy (#{File.basename(__FILE__)})
    Revisions compared: #{initialrev} => #{currentrev}. Trigger: #{triggerrev}

    EOD
    mail = Mail.new do
      from "#{currentcommittername} <#{currentcommitter}@apache.org>"
      to "board@apache.org,#{mail_list}"
      bcc 'notifications@whimsical.apache.org' # keep track of mails
      subject subject
      body body
    end
    if Status.active? or Status.testnode?
      mail.deliver!
    else
      puts stamp "Would have sent: #{subject}"
    end
  end
end

# Process trigger from pubsub
def handle_change(revision)
  puts stamp "handle_change in #{revision}"
  # get the last known revision
  begin
    previous_revision = File.read(PREVIOUS_REVISION).chomp
    puts stamp "Detected last known revision '#{previous_revision}'"
    # get list of commits from initial to current.
    # @return array of entries, each of which is an array of [commitid, committer, datestamp]
    out,_ = ASF::SVN.svn_commits!(SOURCE_URL, previous_revision, revision)
    commits = out.size - 1
    puts stamp "Number of commits found since then: #{commits}"
    raise ArgumentError.new "More than #{MAX_COMMITS} commits detected since #{previous_revision} - this looks wrong" if commits > MAX_COMMITS
    # Get pairs of entries and calculate differences
    out.each_cons(2) do |before, after|
      do_diff(before, after, revision)
      File.write(PREVIOUS_REVISION, after[:revision]) # done that one
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

  ASF::Mail.configure

  if ARGV.delete('--testchange')
    handle_change (ARGV.shift or raise 'Need change id')
    exit
  end

  puts stamp "Starting #{File.basename(__FILE__)} Active?: #{Status.active?}"

  # show initial start
  previous_revision = File.read(PREVIOUS_REVISION).chomp.sub('r','').to_i

  svnrev, err = ASF::SVN.getInfoItem(SOURCE_URL, 'last-changed-revision')
  if svnrev
    latest = svnrev.to_i
  else
    puts stamp err
    latest = 'unknown'
  end

  subject = "Started pubsub-ci-email from revision #{previous_revision}, current #{latest}"
  puts stamp subject

  if previous_revision > latest
    error = "ERROR: Previous revision #{previous_revision} > latest #{latest}!!"
  else
    error = nil
  end

  mail_notify subject, <<~EOD
  This is a test email
  Previous revision #{previous_revision}
  Current  revision #{latest}
  #{error}

  Generated by #{__FILE__}
  EOD

  raise ArgumentError.new error if error

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
    pubsub_CRED = File.read(pubsub_FILE).chomp.split(':') or raise ArgumentError.new 'Missing credentials'
  end

  # Catchup on any missed entries
  handle_change(latest) if latest > previous_revision

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
