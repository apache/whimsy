require 'weakref'

module ASF
  class Member
    include Enumerable
    attr_accessor :full

    def self.find_text_by_id(value)
      new.each do |id, text|
        return text if id==value
      end
      nil
    end

    def self.each(&block)
      new.each(&block)
    end

    def self.list
      result = Hash[self.new.map {|id, text|
        # extract 1st line and remove any trailing /* comment */
        name = text[/(.*?)\n/, 1].sub(/\s+\/\*.*/,'')
        [id, {text: text, name: name}]
      }]

      self.status.each do |name, value|
        result[name]['status'] = value
      end

      result
    end

    def self.find_by_email(value)
      value = value.downcase
      each do |id, text|
        emails(text).each do |email|
          return Person[id] if email.downcase == value
        end
      end
      nil
    end

    def self.status
      begin
        return Hash[@status.to_a] if @status
      rescue
      end

      status = {}
      foundation = ASF::SVN.find('private/foundation')
      return status unless foundation
      sections = File.read("#{foundation}/members.txt").split(/(.*\n===+)/)
      sections.shift(3)
      sections.each_slice(2) do |header, text|
        header.sub!(/s\n=+/,'')
        text.scan(/Avail ID: (.*)/).flatten.each {|id| status[id] = header}
      end

      @status = WeakRef.new(status)
      status
    end

    def each
      foundation = ASF::SVN['private/foundation']
      File.read("#{foundation}/members.txt").split(/^ \*\) /).each do |section|
        id = section[/Avail ID: (.*)/,1]
        yield id, section.sub(/\n.*\n===+\s*?\n(.*\n)+.*/,'').strip if id
      end
      nil
    end

    def self.find(id)
      each {|availid| return true if availid == id}
      return false
    end

    def self.emails(text)
      emails = text.to_s.scan(/Email: (.*(?:\n\s+\S+@.*)*)/).flatten.
        join(' ').split(/\s+/).grep(/@/)
    end

    def self.svn_change
      foundation = ASF::SVN['private/foundation']
      file = "#{foundation}/members.txt"
      return Time.parse(`svn info #{file}`[/Last Changed Date: (.*) \(/, 1]).gmtime
    end
  end

  class Person
    def members_txt
      @members_txt ||= ASF::Member.find_text_by_id(id)
    end

    def member_emails
      ASF::Member.emails(members_txt)
    end
  end
end
