#
# Common access to membership application files
#

### INITIAL RELEASE - SUBJECT TO CHANGE ###

require_relative 'config'
require_relative 'svn'

module ASF
  class MemApps
    @@files = nil
    @@tag = nil

    # list the stems of the files
    def self.stems
      refresh
      @@files.map do |file|
        file.sub(/\.\w+$/, '')
      end
    end

    # list the names of the files (excluding any ones which record emeritus)
    def self.names
      refresh
      @@files
    end

    def self.sanitize(name)
      # Don't transform punctuation into '-'
      ASF::Person.asciize(name.strip.downcase.gsub(/[.,()"]/, ''))
    end

    # search for file name
    # @return filename if it exists, or
    # return full name if filename matches the stem of a file
    def self.search(filename)
      names = self.names()
      if names.include?(filename)
        return filename
      end
      names.each { |name|
        if name.start_with?("#{filename}.")
          return name
        end
      }
      nil
    end

    # find the name of the memapp for a person or nil
    def self.find1st(person)
      self.find(person)[0].first
    end

    # find the memapp for a person; return an array:
    # - [array of files that matched (possibly empty), array of stems that were tried]
    def self.find(person)
      found = [] # matches we found
      names = [] # names we tried
      [
        (person.icla.legal_name rescue nil),
        (person.icla.name rescue nil),
        person.id, # allow match on avalid
        person.member_name # this is slow
      ].uniq.each do |name|
        next unless name
        memapp = self.sanitize(name) # this may generate dupes, so we use uniq below
        names << memapp
        file = self.search(memapp)
        if file
          found << file
        end
      end
      return [found, names.uniq]
    end

    # All files
    def self.files
      refresh
      @@files
    end

    private

    def self.refresh
      cache_dir = ASF::Config.get(:cache)
      ASF::DocumentUtils.update_cache('member_apps', cache_dir)
      @@tag, list = ASF::SVN.getlisting('member_apps', @@tag, true, false, cache_dir)
      if list
        @@files = list
      end
    end
  end
end

# for test purposes
if __FILE__ == $0
  require_relative 'documents'
  puts ASF::MemApps.files.length
  puts ASF::MemApps.names.length
  puts ASF::MemApps.stems.length
end
