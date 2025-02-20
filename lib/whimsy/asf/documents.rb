require 'json'

# Access to documents/* (except member_apps)

module ASF

  module DocumentUtils # This module is also used for member_apps

    MAX_AGE = 600  # 5 minutes

    # N.B. must check :cache config each time to allow for test overrides
    # check cache age and get settings
    def self.check_cache(type, cache_dir: ASF::Config.get(:cache), warn: true)
      file, _ = ASF::SVN.listingNames(type, cache_dir)
      mtime = begin
        File.mtime(file)
      rescue Errno::ENOENT
        0
      end
      age = (Time.now - mtime).to_i
      stale = age > MAX_AGE
      if warn && stale
        Wunderbar.warn "Cache for #{type} is older than #{MAX_AGE} seconds"
        # Wunderbar.warn caller(0, 10).join("\n")
      end
      return [cache_dir, stale, file, age]
    end

    # N.B. must check :cache config each time to allow for test overrides
    # create/update cache file
    def self.update_cache(type, env, cache_dir: ASF::Config.get(:cache), storedates: false, force: false)
      cache_dir, stale, file, age = check_cache(type, cache_dir: cache_dir, warn: false)
      if stale or force
        require 'whimsy/asf/rack'
        ASF::Auth.decode(env)
        # TODO: Downdate to info
        Wunderbar.warn "Updating listing #{file} #{age} as #{env.user}"
        filerev, svnrev = ASF::SVN.updatelisting(type, env.user, env.password, storedates, cache_dir)
        if filerev && svnrev # it worked
          FileUtils.touch file # last time it was checked
        else
          # raise IOError.new("Failed to fetch iclas.txt: #{svnrev}")
          Wunderbar.warn("User #{env.user}: failed to update #{type}: #{svnrev}")
        end
      end
      cache_dir
    end
  end

  # Common class for access to documents/cclas/
  class CCLAFiles

    STEM = 'cclas'

    def self.update_cache(env)
      ASF::DocumentUtils.update_cache(STEM, env)
    end

    # listing of top-level icla file/directory names
    # Directories are listed without trailing "/"
    def self.listnames
      cache_dir = ASF::DocumentUtils.check_cache(STEM).first
      _, list = ASF::SVN.getlisting(STEM, nil, true, false, cache_dir)
      list
    end

    # Does an entry exist?
    def self.exist?(name)
      self.listnames.include?(name)
    end

  end

  # Common class for access to documents/grants/
  class GrantFiles

    STEM = 'grants'

    def self.update_cache(env)
      ASF::DocumentUtils.update_cache(STEM, env)
    end

    # listing of top-level grants file/directory names
    # Directories are listed without trailing "/"
    def self.listnames
      cache_dir = ASF::DocumentUtils.check_cache(STEM).first
      _, list = ASF::SVN.getlisting(STEM, nil, true, false, cache_dir)
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

    STEM = 'iclas'

    def self.update_cache(env)
      ASF::DocumentUtils.update_cache(STEM, env)
    end

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
      # iclas.txt no longer updated by cronjob
      cache_dir = ASF::DocumentUtils.check_cache(STEM).first
      @@tag, list = ASF::SVN.getlisting(STEM, @@tag, false, false, cache_dir)
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

  class WithdrawalRequestFiles

    STEM = 'withdrawn-pending'

    def self.listnames(storedates, env)
      cache_dir = ASF::DocumentUtils.update_cache(STEM, env, storedates: storedates)
      _, list = ASF::SVN.getlisting(STEM, nil, true, storedates, cache_dir)
      list
    end

    def self.refreshnames(storedates, env)
      ASF::DocumentUtils.update_cache(STEM, env, storedates: storedates, force: true)
    end

    # Find the file name (or directory) that matches a person
    # return [svnpath, name, timestamp, epoch (int)] if found
    # return nil if not found
    def self.findpath(userid, env, getDates=false)
      reqdir = ASF::SVN.svnpath!(STEM)
      list, err = ASF::SVN.listnames(reqdir, env.user, env.password, getDates)
      if list # This is a list of [names] or triples [name, ISO timestamp, epoch (int)]
        names = list.select{|x,_y| x.start_with?("#{userid}.") or x == "#{userid}/"} # if there is a sig, then files are in a subdir
        if names.size == 1
          name = names.first
          path = ASF::SVN.svnpath!(STEM, getDates ? name.first : name)
          return [path, name].flatten # this works equally well with or without dates
        end
        return nil
      else
        raise Exception.new("Failed to list #{STEM} files #{err}")
      end
    end
  end
end
