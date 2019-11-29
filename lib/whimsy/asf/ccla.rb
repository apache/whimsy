require 'json'

module ASF

  # Common class for access to documents/cclas/ directory
  class CCLAFiles
    @@CCLAFILES = nil # cache the find if actually needed

    # listing of top-level icla file/directory names
    # Directories are listed without trailing "/"
    def self.listnames
      @@CCLAFILES = ASF::SVN['cclas'] unless @@CCLAFILES
      Dir[File.join(@@CCLAFILES, '*')]
    end

    # Does an entry exist?
    def self.exist?(name)
      @@CCLAFILES = ASF::SVN['cclas'] unless @@CCLAFILES
      Dir[File.join(@@CCLAFILES, name)].any?
    end
  end

end
