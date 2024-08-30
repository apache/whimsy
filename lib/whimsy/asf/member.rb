require 'weakref'
require 'wunderbar'

module ASF
  class Member
    include Enumerable
    @@text = nil
    @@mtime = 0

    def self.mtime
      @@mtime
    end

    # Return the members.txt value associated with a given id
    def self.find_text_by_id(value)
      new.each do |id, text|
        return text if id == value
      end
      nil
    end

    # An iterator that returns a list of ids and associated members.txt entries.
    def self.each(&block)
      new.each(&block)
    end

    # extract 1st line and remove any trailing /* comment */
    def self.get_name(txt)
      txt[/(.*?)\n/, 1].sub(/\s+\/\*.*/, '')
    end

    # return a list of <tt>members.txt</tt> entries as a Hash.  Keys are
    # availids.  Values are a Hash with the following keys:
    # <tt>:text</tt>, <tt>:name</tt>, <tt>"status"</tt>.
    # Active members are those with no 'status' value
    def self.list
      result = Hash[self.new.map {|id, text|
        [id, {text: text, name: self.get_name(text)}]
      }]

      self.status.each do |name, value|
        result[name]['status'] = value
      end

      result
    end

    # return the status of a member:
    # - nil - id not found
    # - :current
    # - :emeritus
    # - :deceased
    def self.member_status(id)
      entry = list[id]
      return nil if entry.nil?
      _entry_status(entry)
    end

    # return the status of an entry:
    # - :current
    # - :emeritus
    # - :deceased
    def self._entry_status(entry)
      status = entry['status']
      case status
      when nil
        :current
      when %r{^Emeritus }
        :emeritus
      when %r{^Deceased }
        :deceased
      else
        raise "Unexpected status: #{status.inspect} for #{id}"
      end
    end

    # return a hash of all the member ids and their status:
    # - :current
    # - :emeritus
    # - :deceased
    def self.member_statuses
      self.list.map { |id, v| [id, self._entry_status(v)]}.to_h
    end

    # Find the ASF::Person associated with a given email
    def self.find_by_email(value)
      value = value.downcase
      each do |id, text|
        emails(text).each do |email|
          return Person.find(id) if email.downcase == value
        end
      end
      nil
    end

    # Return a hash of *non-active* ASF members and their status.  Keys are
    # availids.  Values are strings from the section header under which the
    # member is listed: currently either <tt>Emeritus (Non-voting) Member</tt>
    # or <tt>Deceased Member</tt>.
    # N.B. Does NOT return active members
    def self.status
      begin
        @status = nil if @mtime != @@mtime
        @mtime = @@mtime
        return Hash[@status.to_a] if @status
      rescue
      end

      status = {}
      sections = ASF::Member.text.to_s.split(/(.*\n===+)/)
      sections.shift(3)
      sections.each_slice(2) do |header, text|
        header.sub!(/s\n=+/, '')
        text.scan(/Avail ID: (.*)/).flatten.each {|id| status[id] = header}
      end

      @status = WeakRef.new(status)
      status
    end

    # Return a list of availids of emeritus members
    def self.emeritus
      status.select {|_k, v| v.start_with? 'Emeritus'}.keys
    end

    # Return a list of availids of deceased members
    def self.deceased
      status.select {|_k, v| v.start_with? 'Deceased'}.keys
    end

    # Return a list of availids of current members
    def self.current
      self.list.keys - self.status.keys
    end

    # convert key to symbol: replace non-alphanumeric with '_' and downcase
    def self.key2sym(key)
      Symbol === key ? key.downcase : key.gsub(%r{[^a-zA-Z0-9]}, '_').downcase.to_sym
    end

    # parse a single entry
    # Params:
    # - entry
    # - keys_wanted array of key symbols to retrieve; defaults to ["Email"]
    # - raw: if true, then return raw email entries (with comments)
    # Strings are forced to lower-case and non-alphanumeric replaced with '_'
    def self.parse_entry(entry, keys_wanted=nil, raw=false)
      if keys_wanted.nil?
        keys_wanted = %i{email}
      end
    # init array to collect matching key values, even if repeated
      dict = keys_wanted.map{|k| [k,[]]}.to_h
      current_entry = nil
      entry.each do |line|
        if line =~ %r{^ +([^:]+): *(.*)}
          value = $2.strip # must be done first otherwise $2 is clobbered
          key = key2sym($1)
          if keys_wanted.include? key
            current_entry = dict[key]
            current_entry << value
          else
            current_entry = nil # new key, and not wanted
          end
        elsif current_entry and line.start_with? '    ' # needs to be indented at least this much to be a continuation line
          value = line.strip
          current_entry << value if value.size > 0
        else
          current_entry = nil
        end
      end
      # remove comments from emails?
      unless raw
        if dict.include? :email
          dict[:email] = dict[:email].each.map {|v| v.split(' ').grep(/@/)}.flatten
        end
      end
      dict
    end

    # return all user entries, whether or not they have an id
    # Params: keys_wanted: array of key names to extract and return
    # Returns: array of [status, user name, availid or nil, entry lines, [keys]]
    def self.list_entries(keys_wanted=nil, raw=false, &block)
      Enumerator.new do |y|
      # split by heading underlines; drop text before first
      ASF::Member.text.split("\n").slice_before {|a| a.start_with? '================'}.drop(1).each_with_index do |sect, index|
        status = nil
        # assume the sections remain in the original order
        case index
        when 0
          status = :current
        when 1
          status = :emeritus
        when 2
          status = :other
        when 3
          status = :deceased
        else
          raise ArgumentError, "Unexpected section #{index} #{sect[1..2]}"
        end
        if status
          sect.pop unless status == :deceased # drop next section name (except at the end)
          # extract the entries, dropping the leading text
          sect.slice_before {|a| a.start_with? ' *)'}.drop(1).each do |entry|
            # we always want the name
            name = entry.first[4..-1].sub(%r{ +/\*.+}, '') # skip ' *) '; drop comment
            ids = []
            entry.each {|e| ids << $1 if e =~ %r{^ +Avail ID: *(\S+)}}
            if ids.length > 1
              Wunderbar.error "Duplicate ids: #{ids} in #{name} entry"
            end
            if keys_wanted
              y.yield [status, name, ids.first, entry, self.parse_entry(entry, keys_wanted, raw)]
            else
              y.yield [status, name, ids.first, entry]
            end
          end
        else # can this happen?
          raise ArgumentError, 'Unexpected section with nil status!'
        end
      end
      end.each(&block)
    end

    # An iterator that returns a list of ids and associated members.txt entries.
    def each
      ASF::Member.text.to_s.split(/^ \*\) /).each do |section|
        id = section[/Avail ID: (.*)/, 1]
        yield id, section.sub(/\n.*\n===+\s*?\n(.*\n)+.*/, '').strip if id
      end
      nil
    end

    # Determine if the person associated with a given id is an ASF member.
    # Includes emeritus and deceased members
    # Returns a boolean value.
    def self.find(id)
      each {|availid| return true if availid == id}
      return false
    end

    # extract member emails from members.txt entry
    def self.emails(text)
      # RE looks for optional continuation lines starting with spaces followed by nonspaces followed by '@'
      text.to_s.scan(/Email: (.*(?:\n\s+\S+@.*)*)/).flatten.
        join(' ').split(/\s+/).grep(/@/)
    end

    # Return the Last Changed Date for <tt>members.txt</tt> in svn as
    # a <tt>Time</tt> object.
    def self.svn_change
      file = File.join(ASF::SVN['foundation'], 'members.txt')
      return Time.parse(ASF::SVN.getInfoItem(file, 'last-changed-date')).gmtime
    end

    # sort an entire members.txt file
    def self.sort(source)
      # split into sections
      sections = source.split(/^([A-Z].*\n===+\n\n)/)

      # sort sections that contain names
      sections.map! do |section|
        next section unless section =~ /^\s\*\)\s/

        # split into entries, and normalize those entries
        entries = section.split(/^\s\*\)\s/)
        header = entries.shift
        entries.map! {|entry| ' *) ' + entry.strip + "\n\n"}

        # sort the entries
        entries.sort_by! do |entry|
          ASF::Person.sortable_name(entry[/\)\s(.*?)\s*(\/\*|$)/, 1])
        end

        header + entries.join
      end

      sections.join
    end

    # cache the contents of members.txt.  Primary purpose isn't performance,
    # but rather to have a local copy that can be updated and used until
    # the svn working copy catches up
    def self.text
      foundation = ASF::SVN.find('foundation')
      return nil unless foundation

      begin
        text = @@text[0..-1] if @@text
      rescue WeakRef::RefError
        @@mtime = 0
      end

      member_file = File.join(foundation, 'members.txt')
      member_time = File.mtime(member_file)
      if member_time.to_i > @@mtime.to_i
        @@mtime = member_time
        text = File.read(member_file)
        @@text = WeakRef.new(text)
      end

      text
    end

    # normalize text: sort and update active count
    def self.normalize(text)
      text = ASF::Member.sort(text)
      pattern = /^Active.*?^=+\n+(.*?)^Emeritus/m
      text[/We now number (\d+) active members\./, 1] =
        text[pattern].scan(/^\s\*\)\s/).length.to_s
      text
    end

    # update local copy of members.txt
    def self.text=(text)
      text = self.normalize(text)
      # save
      @@mtime = Time.now
      @@text = WeakRef.new(text)
    end

    # create an entry in the standard format:
    # *) First Last
    #    Street
    #    Town
    #    Country
    #    Email: id@apache.org
    #      Tel: 1234
    # Forms on File: ASF Membership Application
    # Avail ID: id
    # Parameters:
    # fields - hash:
    #  :fullname - required
    #  :address - required, multi-line allowed
    #  :availid - required
    #  :email - optional
    #  :country - optional
    #  :tele - optional
    #  :fax - optional
    def self.make_entry(fields={})
      fullname = fields[:fullname] or raise ArgumentError.new(':fullname is required')
      address = fields[:address] || '<postal address>'
      availid = fields[:availid] or raise ArgumentError.new(':availid is required')
      email = fields[:email] || "#{availid}@apache.org"
      country = fields[:country] || '<Country>'
      tele = fields[:tele] || '<phone number>'
      fax = fields[:fax] || ''
      [
        fullname, # will be prefixed by ' *) '
        # Each line of address is indented
        (address.gsub(/^/, '    ').gsub(/\r/, '') unless address.empty?),
        ("    #{country}"     unless country.empty?),
        ("    Email: #{email}" unless email.empty?),
        ("      Tel: #{tele}" unless tele.empty?),
        ("      Fax: #{fax}"  unless fax.empty?),
        ' Forms on File: ASF Membership Application',
        " Avail ID: #{availid}"
      ].compact.join("\n") + "\n"
    end
  end

  class Person
    # text entry from <tt>members.txt</tt>.  If <tt>full</tt> is <tt>true</tt>,
    # this will also include the text delimiters.
    def members_txt(full = false)
      prefix, suffix = ' *) ', "\n\n" if full
      # Is the cached text still valid?
      unless @members_time == ASF::Member.mtime
        @members_txt = nil
      end
      # cache the text and its time (may be changed by the find operation)
      @members_txt ||= ASF::Member.find_text_by_id(id)
      @members_time = ASF::Member.mtime
      "#{prefix}#{@members_txt}#{suffix}" if @members_txt
    end

    # email addresses from members.txt
    def member_emails
      ASF::Member.emails(members_txt)
    end

    # Person's name as found in members.txt
    def member_name
      ASF::Member.get_name(members_txt) if members_txt
    end
  end
end

if __FILE__ == $0
  $LOAD_PATH.unshift '/srv/whimsy/lib'
  # N.B. Require 'whimsy/asf' causes error: superclass mismatch for class Person
  require 'whimsy/asf/config'
  require 'whimsy/asf/svn'
  puts ASF::Member.list.size
  puts ASF::Member.status.size
  puts ASF::Member.text.size
  ids = 0
  ASF::Member.each {|_| ids += 1}
  puts ids
end
