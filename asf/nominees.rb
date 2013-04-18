module ASF

  class Person < Base
  
    def self.member_nominees
      return @member_nominees if @member_nominees

      foundation = ASF::SVN['private/foundation/Meetings']
      text = File.read "#{foundation}/20130521/nominated-members.txt"

      nominations = text.split(/^\s*---+\s*/)
      nominations.shift(2)

      nominees = {}
      nominations.each do |nomination|
        id = nomination[/^\s?\w+.*<(\S+)@apache.org>/,1]
        id ||= nomination[/^\s?\w+.*\(([a-z]+)\)/,1]

        next unless id

        nominees[find(id)] = nomination
      end

      @member_nominees = nominees
    end

    def member_nomination
      Person.member_nominees[self]
    end
  end
end
