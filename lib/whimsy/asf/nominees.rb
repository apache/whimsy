require 'weakref'

module ASF

  class Person < Base

    # Return a hash of nominated members.  Keys are ASF::Person objects,
    # values are the nomination text.
    def self.member_nominees
      begin
        return Hash[@member_nominees.to_a] if @member_nominees
      rescue
      end

      meetings = ASF::SVN['Meetings']
      nominations = Dir[File.join(meetings, '*', 'nominated-members.txt')].max

      # ensure non-UTF-8 chars don't cause a crash
      nominations = File.read(nominations).encode("utf-8", "utf-8", :invalid => :replace).split(/^\s*---+--\s*/)
      nominations.shift(2)

      nominees = {}
      nominations.each do |nomination|

        # leading space is swallowed by the split; match against
        # <NOMINATED PERSON'S APACHE ID> <PUBLIC NAME>
        id = nomination[/\A(\S+)/, 1]
        id ||= nomination[/^\s?\w+.*<(\S+)@apache.org>/, 1]
        id ||= nomination[/^\s?\w+.*\((\S+)@apache.org\)/, 1]
        id ||= nomination[/^\s?\w+.*\(([a-z]+)\)/, 1]

        next unless id

        nominees[find(id)] = nomination
      end

      @member_nominees = WeakRef.new(nominees)
      nominees
    end

    # Return the member nomination text for this individual
    def member_nomination
      @member_nomination ||= Person.member_nominees[self]
    end
  end
end
