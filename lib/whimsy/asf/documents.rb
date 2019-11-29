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
    @@tag = nil
    # search icla files to find match with claRef
    # Returns the basename or nil if no match
    def self.match_claRef(claRef)
      @@tag, list = ASF::SVN.getlisting('iclas', @@tag)
      if list
        @@list = list.map
      end
      # Match either full name (e.g. directory) or stem (e.g. name.pdf)
      file = @@list.select{|l| l == claRef || l.start_with?("#{claRef}.") }.first
    end
  end

end
