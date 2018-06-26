#
# Common access to membership application files
#

### INITIAL RELEASE - SUBJECT TO CHANGE ###

require_relative 'config'
require_relative 'svn'

module MemApps
  @@MEMAPPS = ASF::SVN['member_apps']
  @@files = nil
  @@mtime = nil

  # list the stems of the files (excluding any ones which record emeritus)
  def self.stems
    refresh
    apps = @@files.reject{|f| f =~ /_emeritus\.\w+$/}.map do |file|
      File.basename(file).sub(/\.\w+$/, '')
    end
    apps
  end

  # list the names of the files (excluding any ones which record emeritus)
  def self.names
    refresh
    @@files.reject{|f| f =~ /_emeritus\.\w+$/}
  end

  # names of emeritus files
  def self.emeritus
    refresh
    apps = @@files.select {|f| f =~ /_emeritus\.\w+$/}.map do |file|
      File.basename(file).sub(/_emeritus\.\w+$/, '')
    end
    apps
  end

  def self.sanitize(name)
    name.strip.downcase.
      gsub(/[.,()"]/,''). # drop punctuation (keep ')
      # drop most accents
      gsub('ú','u').gsub(/[óøò]/,'o').gsub(/[čć]/,'c').gsub(/[éëè]/,'e').gsub('á','a').gsub('ž','z').gsub('í','i').
      gsub(/\s+/, '-').untaint # space to '-'
  end

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

  # find the memapp for a person; return an array:
  # - [array of files that matched (possibly empty), array of stems that were tried]
  def self.find(person)
    found=[] # matches we found
    names=[] # names we tried
    [
      (person.icla.legal_name rescue nil), 
      (person.icla.name rescue nil),
      person.member_name
    ].uniq.each do |name|
      next unless name
      memapp = self.sanitize(name) # this may generate dupes, so we use uniq below
      names << memapp
      file = self.search(memapp)
      if file
        found << File.basename(file)
      end
    end
    return [found, names.uniq]
  end

  # All files, including emeritus
  def self.files
    refresh
    @@files
  end

  private

  def self.refresh
    if File.mtime(@@MEMAPPS) != @@mtime
      @@files = Dir[File.join(@@MEMAPPS, '*')].map { |p|
        File.basename(p)
      }
      @@mtime = File.mtime(@@MEMAPPS)
    end
  end
end

# for test purposes
if __FILE__ == $0
  puts MemApps.files.length
  puts MemApps.names.length
  puts MemApps.stems.length
  puts MemApps.emeritus.length
end
