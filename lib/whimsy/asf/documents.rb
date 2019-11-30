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

    # search icla files to find match with claRef
    # matches if the input matches the full name of a file or directory or 
    # it matches with an extension
    # Returns the basename or nil if no match
    def self.match_claRef(claRef)
      # Match either full name (e.g. directory) or stem (e.g. name.pdf)
      file = listnames.select{|l| l.chomp('/') == claRef || l.start_with?("#{claRef}.") }.map {|m| m.chomp('/')}.first
    end

    # is the name a directory?
    def self.Dir?(name)
      listnames.include? name + '/'
    end

    # return a list of names matching stem.*
    # Does not return directories
    def self.matchStem(stem)
    listnames.select{|l| ! l.end_with?('/') && l.start_with?("#{stem}.")}
    end

    # This returns the list of names in the top-level directory
    # directory names are terminated by '/'
    def self.listnames
      @@tag, list = ASF::SVN.getlisting('iclas', @@tag, false)
      if list
        @@list = list
      end
      @@list      
    end
  end

end
