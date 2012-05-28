module ASF

  class Person < Base
  
    def self.member_watch_list
      return @member_watch_list if @member_watch_list

      foundation = ASF::SVN['private/foundation']
      text = File.read "#{foundation}/potential-member-watch-list.txt"

      nominations = text.scan(/^\s+\*\)\s+\w.*?\n\s*(?:---|\Z)/m)

      i = 0
      member_watch_list = {}
      nominations.each do |nomination|
        id = nil
        name = nomination[/\*\)\s+(.+?)\s+(\(|\<|$)/,1]
        id ||= nomination[/\*\)\s.+?\s\((.*?)\)/,1]
        id ||= nomination[/\*\)\s.+?\s<(.*?)@apache.org>/,1]

        unless id
          id = "notinavail_#{i+=1}"
          find(id).attrs['cn'] = name
        end

        member_watch_list[find(id)] = nomination
      end

      @member_watch_list = member_watch_list
    end

    def member_watch
      text = Person.member_watch_list[self]
      if text
        text.sub!(/\A\s*\n/,'')
        text.sub!(/\n---\Z/,'')
      end
      text
    end
  end
end
