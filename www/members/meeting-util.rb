#!/usr/bin/env ruby
# Utility methods and structs related to Member's Meetings
# NOTE: Assumes 21st century '2*'
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
require 'json'

class MeetingUtil
  RECORDS = ASF::SVN.svnurl!('Meetings')
  MEETING_FILES = { # Filename in meeting dir, pathname to another deployed tool, or URL
    'README.txt' => 'README For Meeting Process And Roll Call',
    'nomination_of_board.txt' => 'How To Nominate Someone For Board',
    'nomination_of_members.txt' => 'How To Nominate A New Member',
    '/members/proxy.cgi' => 'How To Submit A Proxy/Check Your Proxies',
    'https://www.apache.org/foundation/governance/meetings' => 'How Voting Via Email Works',
    'agenda.txt' => 'Official Meeting Agenda',
    'board_ballot.txt' => 'Official Board Candidate Ballots',
    'nominated-members.txt' => 'Official New Member Nominees/Seconds',
    'proxies' => 'Official List Of Meeting Proxies',
    'record' => 'Official List Of Voting Members',
    'attend' => 'Official List Of Meeting Attendees (afterwards)',
    'voter-tally' => 'Official List Of Who Voted (afterwards)',
    'raw_board_votes.txt' => 'Official List Of Votes For Board (afterwards)',
    'raw-irc-log' => 'ASFBot logs all postings on #asfmembers during meeting'
  }

  # Calculate how many members required to attend first half for quorum
  def self.calculate_quorum(mtg_dir)
    begin
      num_members = File.read(File.join(mtg_dir, 'record')).each_line.count
      quorum_need = (num_members + 2) / 3
      num_proxies = Dir[File.join(mtg_dir, 'proxies-received', '*')].count
      attend_irc = quorum_need - num_proxies
    rescue StandardError => e
      # Ensure we can't break rest of script
      puts "ERROR: #{e}"
      return 0, 0, 0, 0
    end
    return num_members, quorum_need, num_proxies, attend_irc
  end
  
  # get list of proxy volunteers
  def self.getVolunteers(mtg_dir)
    lines = IO.read(File.join(mtg_dir, 'proxies'))
    # split by ---- underlines, then by blank lines; pick second para and drop leading spaces
    volunteers = lines.split(/^-----------/)[1].split(/\n\n/)[1].scan(/^\ +(\S.*$)/).flatten
    
  end
  # Get info about current users's proxying
  # @return "help text", ["id | name (proxy)", ...] if they are a proxy for other(s)
  # @return "You have already submitted a proxy form" to someone else
  # @return nil otherwise
  def self.is_user_proxied(mtg_dir, id)
    user = ASF::Person.find(id)
    lines = IO.read(File.join(mtg_dir, 'proxies'))
    proxylist = lines.scan(/\s\s(.{25})(.*?)\((.*?)\)/) # [["Shane Curcuru    ", "David Fisher ", "wave"], ...]
    help = nil
    copypasta = [] # theiravailid | Their Name in Rolls (proxy)
    begin
      proxylist.each do |arr|
        if user.cn == arr[0].strip
          copypasta << "#{arr[2].ljust(12)} | #{arr[1].strip} (proxy)"
        elsif user.id == arr[2]
          help = "NOTE: You have already submitted a proxy form for #{arr[0].strip} to mark your attendance (be sure they know to mark you at Roll Call)! "
        end
      end
    rescue StandardError => e
      (help ||= "") << "ERROR, could not read LDAP, proxy data may not be correct: #{e.message}"
    end
    if copypasta.empty?
      return help
    else
      (help ||= "") << "During the meeting, to mark your proxies' attendance, AFTER the 2. Roll Call is called, you may copy/paste the below lines to mark your and your proxies attendance."
      copypasta.unshift("#{user.id.ljust(12)} | #{user.cn}")
      return help, copypasta
    end
  end
  
  # Get the latest available Meetings dir
  def self.get_latest(mtg_root)
    return Dir[File.join(mtg_root, '2*')].sort.last
  end
  # Get the second latest available Meetings dir
  def self.get_previous(mtg_root)
    return Dir[File.join(mtg_root, '2*')].sort[-2]
  end
  # Read attendance.json file
  def self.get_attendance(mtg_root)
    return JSON.parse(IO.read(File.join(mtg_root, 'attendance.json')))
  end

  # Parse all memapp-received.txt files to get better set of names
  # @see whimsy/www/members/attendance-xcheck.cgi
  def self.read_memapps(dir)
    memapps = Hash.new('unknown')
    Dir[File.join(dir, '*', 'memapp-received.txt')].each do |received|
      meeting = File.basename(File.dirname(received))
      next if meeting.include? 'template'
      text = File.read(received)
      list = text.scan(/(.+)\s<(.*)@.*>.*Yes/i)
      if list.empty?
        list = text.scan(/^(?:no\s*)*(?:yes\s+)+(\w\S*)\s+(.*)\s*/)
      else
        # reverse order of id name type files
        list.each {|a| a[0], a[1] = a[1], a[0] }
      end
      list.each { |itm| memapps[itm[1].strip] = [itm[0], meeting] }
    end
    return memapps
  end

  # Annotate the attendance.json file with cohorts by id
  # This allows easy use by other tools
  def self.annotate_attendance(dir)
    attendance = JSON.parse(IO.read(File.join(dir, 'attendance.json')))
    memapps = read_memapps(dir)
    iclas = ASF::ICLA.preload
    memapp_map = JSON.parse(IO.read(File.join(dir, 'memapp-map.json')))
    attendance['cohorts'] = {}
    attendance['unmatched'] = []
    attendance['members'].each do |date, ary|
      ary.each do |nam|
        found = iclas.select{|i| i.icla.legal_name == nam}
        found = iclas.select{|i| i.icla.name == nam} if found.empty?
        if found.empty?
          if memapps.has_key?(nam)
            attendance['cohorts'][memapps[nam][0]] = date
          elsif memapp_map.has_key?(nam)
            attendance['cohorts'][memapp_map[nam]] = date
          else
            attendance['unmatched'] << nam
          end
        else
          attendance['cohorts'][found[0].icla.id] = date
        end
      end
    end
    File.open(File.join(dir, 'attendance-cohorts.json'), 'w') do |f| # Do not overwrite blindly; manual copy if desired
      f.puts JSON.pretty_generate(attendance)
    end
  end
end

# ## ### #### ##### ######
# Main method for command line use
if __FILE__ == $PROGRAM_NAME
  dir = ARGV[0]
  dir ||= '.'
  MeetingUtil.annotate_attendance(dir)
  puts "DONE, check attendance-cohorts.json"
end
