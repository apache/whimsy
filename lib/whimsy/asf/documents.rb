require 'json'

# Access to documents/* (except member_apps)

module ASF

  # Common class for access to documents/cclas/
  class CCLAFiles

    # listing of top-level icla file/directory names
    # Directories are listed without trailing "/"
    def self.listnames
      _, list = ASF::SVN.getlisting('cclas') # do we need to cache the listing?
      list
    end

    # Does an entry exist?
    def self.exist?(name)
      self.listnames.include?(name)
    end
    
  end

  # Common class for access to documents/cclas/
  class GrantFiles

    # listing of top-level grants file/directory names
    # Directories are listed without trailing "/"
    def self.listnames
      _, list = ASF::SVN.getlisting('grants') # do we need to cache the listing?
      list
    end

    # Does an entry exist?
    def self.exist?(name)
      self.listnames.include?(name)
    end
    
  end

  # Common class for access to documents/iclas/ directory
  class ICLAFiles
    @@tag = nil # probably worth caching iclas
    @@list = nil # this list includes trailing '/' so can detect directories correctly
    # Turns out that select{|l| ! l.end_with?('/') && l.start_with?("#{stem}.")} is quite slow,
    # so create hashes from the list
    @@h_claRef = nil # for matching claRefs
    @@h_stem = nil # for matching stems

    # search icla files to find match with claRef
    # matches if the input matches the full name of a file or directory or 
    # it matches with an extension
    # Returns the basename or nil if no match
    def self.match_claRef(claRef)
      unless @@h_claRef
        h_claRef = Hash.new
        listnames.map do |l|
          # Match either full name (e.g. directory) or stem (e.g. name.pdf)
          if l.end_with? '/'
            h_claRef[l.chomp('/')] = l.chomp('/')
          elsif l.include?('.')
            h_claRef[l.split('.')[0]] = l
          else
            h_claRef[l] = l
          end
        end
        @@h_claRef = h_claRef
      end
      @@h_claRef[claRef]
    end

# is the name a directory?
    def self.Dir?(name)
      listnames.include? name + '/'
    end

    # return a list of names matching stem.*
    # Does not return directories
    def self.matchStem(stem)
      unless @@h_stem
        h_stem = Hash.new{|h,k| h[k] = []}
          listnames.map do |l|
            h_stem[l.split('.')[0]] << l unless l.end_with?('/')
          end
        @@h_stem = h_stem
      end
      @@h_stem[stem]
    end

    # This returns the list of names in the top-level directory
    # directory names are terminated by '/'
    def self.listnames
      @@tag, list = ASF::SVN.getlisting('iclas', @@tag, false)
      if list # we have a new list
        # update the list cache
        @@list = list
        # clear the hash caches
        @@h_claRef = nil
        @@h_stem = nil
      end
      @@list      
    end
  end

  class EmeritusFiles
    def self.listnames
      _, list = ASF::SVN.getlisting('emeritus')
      list
    end

    def self.find(person)
      # TODO use common stem name method
      name = (person.attrs['cn'].first rescue person.member_name).force_encoding('utf-8').
        downcase.gsub(' ','-').gsub(/[^a-z0-9-]+/,'') rescue nil
      id = person.id
      files = self.listnames.find_all do |file|
        stem = file.split('.')[0] # directories don't have a trailing /
        stem == id or stem == name
      end
      # Only valid if we match a single file or directory
      if files.length == 1
        files.first
      else
        nil
      end
    end
  end

  class EmeritusRequestFiles < EmeritusFiles
    def self.listnames
      _, list = ASF::SVN.getlisting('emeritus-requests-received')
      list
    end
  end

class EmeritusRescindedFiles < EmeritusFiles
  def self.listnames
    _, list = ASF::SVN.getlisting('emeritus-requests-rescinded')
    list
  end
end

class EmeritusRejoinedFiles < EmeritusFiles
  def self.listnames
    _, list = ASF::SVN.getlisting('emeritus-rejoined')
    list
  end
end

end
