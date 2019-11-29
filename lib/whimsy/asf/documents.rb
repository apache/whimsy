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
    @@ICLAFILES = nil # cache the find if actually needed
    # search icla files to find match with claRef
    # Returns the basename or nil if no match
    def self.match_claRef(claRef)
      @@ICLAFILES = ASF::SVN['iclas'] unless @@ICLAFILES
      file = Dir[File.join(@@ICLAFILES, claRef), File.join(@@ICLAFILES, "#{claRef}.*")].first
      File.basename(file) if file
    end

    # listing of top-level icla file/directory names
    # Directories are listed without trailing "/"
    def self.listnames
      @@ICLAFILES = ASF::SVN['iclas'] unless @@ICLAFILES
      Dir[File.join(@@ICLAFILES, '*')]
    end
  end

end
