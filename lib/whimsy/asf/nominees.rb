require 'weakref'

module ASF

  class Person < Base
  
    def self.member_nominees
      begin
        return Hash[@member_nominees.to_a] if @member_nominees
      rescue NoMethodError, WeakRef::RefError
      end

      meetings = ASF::SVN['private/foundation/Meetings']
      nominations = Dir["#{meetings}/*/nominated-members.txt"].sort.last.untaint

      nominations = File.read(nominations).split(/^\s*---+\s*/)
      nominations.shift(2)

      nominees = {}
      nominations.each do |nomination|
        id = nomination[/^\s?\w+.*<(\S+)@apache.org>/,1]
        id ||= nomination[/^\s?\w+.*\((\S+)@apache.org\)/,1]
        id ||= nomination[/^\s?\w+.*\(([a-z]+)\)/,1]

        next unless id

        nominees[find(id)] = nomination
      end

      @member_nominees = WeakRef.new(nominees)
      nominees
    end

    def member_nomination
      Person.member_nominees[self]
    end
  end
end
