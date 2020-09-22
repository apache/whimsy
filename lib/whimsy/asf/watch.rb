module ASF

  class Person < Base

    # Return a hash of individuals in the member watch list.  Keys are
    # ASF::Person objects, values are the text from
    # <tt>potential-member-watch-list.txt</tt>..
    def self.member_watch_list
      return @member_watch_list if @member_watch_list

      text = File.read File.join(ASF::SVN['foundation'], 'potential-member-watch-list.txt')

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

    # This person's entry in <tt>potential-member-watch-list.txt</tt>.
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
