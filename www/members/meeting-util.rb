# Utility methods and structs related to Member's Meetings
# NOTE: Assumes 21st century

class MeetingUtil

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
  
  # Read mapping of labels to fields
  def self.get_latest(mtg_root)
    return Dir[File.join(mtg_root, '2*')].sort.last
  end
  # Read mapping of labels to fields
  def self.get_previous(mtg_root)
    return Dir[File.join(mtg_root, '2*')].sort[-2]
  end

end