#!/usr/bin/env ruby
# Utility methods and structs related to Member's Meetings
# NOTE: Assumes 21st century '2*'
$LOAD_PATH.unshift '/srv/whimsy/lib' if __FILE__ == $PROGRAM_NAME
require 'whimsy/asf'
require 'json'

module ASF
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
        begin
          num_members = File.read(File.join(mtg_dir, 'record')).each_line.count
        rescue
          num_members = ASF::Member.list.length - ASF::Member.status.length
        end
        quorum_need = (num_members + 2) / 3
        num_proxies = Dir[File.join(mtg_dir, 'proxies-received', '*')].count
        attend_irc = quorum_need - num_proxies
        attend_irc = 0 if attend_irc < 0 # allow for more proxies than quorum
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
      lines.split(/^-----------/)[1].split(/\n\n/)[1].scan(/^\ +(\S.*$)/).flatten
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

    # Get the latest completed Meetings dir (i.e. has raw-irc-log)
    # TODO: is that the most appropriate file to check?
    def self.get_latest_completed(mtg_root, sentinel='raw-irc-log')
      return Dir[File.join(mtg_root, '2*')].select {|d| File.exist? File.join(d, sentinel) }.max
    end
    # Get the latest available Meetings dir
    def self.get_latest(mtg_root)
      return Dir[File.join(mtg_root, '2*')].max
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
        next unless date.start_with? '20' # exclude 'active'
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

    # Precompute matrix and dates from attendance
    def self.get_attend_matrices(dir)
      attendance = MeetingUtil.get_attendance(dir)

      # extract and format dates
      dates = attendance['dates'].sort.
        map {|date| Date.parse(date).strftime('%Y-%b')}

      # compute mappings of names to ids
      members = ASF::Member.list
      active = Hash[members.select {|_id, data| not data['status']}]
      nameMap = Hash[members.map {|id, data| [id, data[:name]]}]
      idMap = Hash[nameMap.to_a.map(&:reverse)]

      # analyze attendance
      matrix = attendance['matrix'].map do |name, meetings|
        id = idMap[name]
        next unless id and active[id]

        # exclude 'active entry'
        data = meetings.select {|key, value| key.start_with? '20'}.
          sort.reverse.map(&:last)

        first = data.length
        missed = (data.index {|datum| datum != '-'} || data.length)

        [id, name, first, missed]
      end

      return attendance, matrix.compact, dates, nameMap
    end

    # return a function to determine the current status of a member by id
    def self.current_status(cur_mtg_dir)
      proxies = Dir["#{cur_mtg_dir}/proxies-received/*"].
        map {|file| File.basename(file, '.*')}

      _tag,emeritus = ASF::SVN.getlisting('emeritus-requests-received')
      emeritus.map! {|file| File.basename(file, '.*')}

      lambda do |id|
        if emeritus.include? id
          'Emeritus request received'
        elsif proxies.include? id
          'Proxy received'
        else
          'No response'
        end
      end
    end

    # return the current status of all inactive members
    def self.tracker(meetingsMissed)
      meetings = ASF::SVN['Meetings']
      cur_mtg_dir = MeetingUtil.get_latest(meetings)
      current_status = self.current_status(cur_mtg_dir)

      _attendance, matrix, dates, _nameMap = MeetingUtil.get_attend_matrices(meetings)
      inactive = matrix.select do |id, _name, _first, missed|
        id and missed >= meetingsMissed
      end

      Hash[inactive.map {|id, name, first, missed|
        [id, {
          'name' => name,
          'missed' => missed,
          'status' => current_status[id],
          'since' => dates[-first-1] || dates.first,
          'last' => dates[-missed-1]
        }]
      }]
    end
  end
end

# ## ### #### ##### ######
# Main method for command line use
if __FILE__ == $PROGRAM_NAME
  dir = ARGV[0]
  dir ||= '.'
  ASF::MeetingUtil.annotate_attendance(dir)
  puts "DONE, check attendance-cohorts.json"
end
