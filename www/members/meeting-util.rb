# Utility methods and structs related to Member's Meetings
# NOTE: Assumes 21st century '2*'
require 'json'

class MeetingUtil
  RECORDS = 'https://svn.apache.org/repos/private/foundation/Meetings'
  MEETING_FILES = { # Filename in meeting dir, or pathname to another tool
    'README.txt' => 'README For Meeting Process',
    'nomination_of_board.txt' => 'How To Nominate Someone For Board',
    'nomination_of_members.txt' => 'How To Nominate A New Member',
    '/members/proxy.cgi' => 'How To Submit A Proxy/Check Your Proxies',
    'https://www.apache.org/foundation/governance/meetings' => 'How Voting Via Email Works',
    'agenda.txt' => 'Official Meeting Agenda',
    'board_ballot.txt' => 'Official Board Candidate Ballots',
    'proxies' => 'Official List Of Meeting Proxies',
    'record' => 'Official List Of Voting Members',
    'attend' => 'Official List Of Meeting Attendees (afterwards)',
    'voter-tally' => 'Official List Of Who Voted (afterwards)',
    'raw_board_votes.txt' => 'Official List Of Votes For Board (afterwards)'
  }

  # Calculate how many members required to attend first half for quorum
  def self.calculate_quorum(mtg_dir)
    begin
      num_members = File.read(File.join(mtg_dir, 'record')).each_line.count
      quorum_need = num_members / 3
      num_proxies = Dir[File.join(mtg_dir, 'proxies-received', '*')].count
      attend_irc = quorum_need - num_proxies
    rescue StandardError => e
      # Ensure we can't break rest of script
      puts "ERROR: #{e}"
      return 0, 0, 0, 0
    end
    return num_members, quorum_need, num_proxies, attend_irc
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

end