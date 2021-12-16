require 'json'

# Access to documents/* (except member_apps)

module ASF

  module DocumentUtils
    # create/update cache file
    def self.update_cache(type, cache_dir)
      file, _ = ASF::SVN.listingNames(type, cache_dir)
      mtime = begin
        File.mtime(file)
      rescue Errno::ENOENT
        0
      end
      age = (Time.now - mtime).to_i
      if age > 600 # 5 minutes
        Wunderbar.warn "Updating listing #{file} #{age}"
        require 'whimsy/asf/rack'
        ASF::Auth.decode(env = {})
        filerev, svnrev = ASF::SVN.updatelisting(type, env.user, env.password, false, cache_dir)
        if filerev && svnrev # it worked
          FileUtils.touch file # last time it was checked
        else
          # raise IOError.new("Failed to fetch iclas.txt: #{svnrev}")
          Wunderbar.warn("User #{env.user}: failed to update #{type}: #{svnrev}")
        end
      end
    end
  end

  # Common class for access to documents/cclas/
  class CCLAFiles

    # listing of top-level icla file/directory names
    # Directories are listed without trailing "/"
    def self.listnames
      cache_dir = ASF::Config.get(:cache)
      DocumentUtils.update_cache('cclas', cache_dir)
      _, list = ASF::SVN.getlisting('cclas', nil, true, false, cache_dir)
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
      cache_dir = ASF::Config.get(:cache)
      DocumentUtils.update_cache('grants', cache_dir)
      _, list = ASF::SVN.getlisting('grants', nil, true, false, cache_dir) # do we need to cache the listing?
      list
    end

    # Does an entry exist?
    def self.exist?(name)
      self.listnames.include?(name)
    end

  end

  # Common class for access to documents/iclas/ directory
  # Only intended for use by secretary team
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
        h_claRef = {}
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
        h_stem = Hash.new {|h, k| h[k] = []}
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
      iclas = 'iclas'
      cache_dir = ASF::Config.get(:cache)
      # iclas.txt no longer updated by cronjob
      DocumentUtils.update_cache(iclas, cache_dir)
      @@tag, list = ASF::SVN.getlisting(iclas, @@tag, false, false, cache_dir)
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
    @base = 'emeritus'
    def self.listnames(getDates=false)
      _, list = ASF::SVN.getlisting(@base, nil, true, getDates)
      list
    end

    # Find the file name that matches a person
    # return nil if not exactly one match
    # TODO: should it raise an error on multiple matches?
    def self.find(person, getDate=false)
      # TODO use common stem name method
      name = (person.attrs['cn'].first rescue person.member_name).force_encoding('utf-8').
        downcase.gsub(' ', '-').gsub(/[^a-z0-9-]+/, '') rescue nil
      id = person.id
      files = self.listnames(getDate).find_all do |file|
        if file.is_a?(Array) # we have [epoch, file]
          file = file[1]
        end
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

    # return the svn path to an arbitrary file
    def self.svnpath!(file)
      ASF::SVN.svnpath!(@base, file)
    end

    # Find the svnpath to the file for a person
    # Returns
    # svnpath, filename
    # or
    # nil, nil if not found
    def self.findpath(person)
      path = nil
      file = find(person)
      path = svnpath!(file) if file
      [path, file]
    end

    # Extract the file name from an svn url
    # param rooturl the svn url of the directory
    # param fileurl the svn url of the complete file
    # return the file name or nil if the file is not in the directory
    def self.extractfilenamefrom(rooturl, fileurl)
      return nil unless fileurl

      # does the root match the file url?
      index = fileurl.index(rooturl)
      return nil unless index.zero?

      # root matches, return file name (end of fileurl)
      fileurl[rooturl.length..-1]
    end

    # Extract the file name if it is in emeritus directory
    # nil if it is not in this directory
    def self.extractfilename(fileurl)
      return nil unless fileurl

      root_url = ASF::SVN.svnurl(@base) + '/'
      extractfilenamefrom(root_url, fileurl)
    end
  end

  class EmeritusRequestFiles < EmeritusFiles
    @base = 'emeritus-requests-received'
  end

  class EmeritusRescindedFiles < EmeritusFiles
    @base = 'emeritus-requests-rescinded'
  end

  class EmeritusReinstatedFiles < EmeritusFiles
    @base = 'emeritus-reinstated'
  end

  class COIFiles < EmeritusFiles
    @base = 'conflict-of-interest'
  end

end
