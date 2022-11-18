require 'fileutils'
require 'digest'
require 'net/http'
require 'wunderbar'

# Simple cache for HTTP(S) text files
class Cache
  # Don't bother checking cache entries that are younger (seconds)
  attr_accessor :minage

  # Is the cache enabled?
  attr_reader :enabled

  # Create the cache
  #
  # Parameters:
  # - dir - where to store the files. Path is relative to '/tmp/whimsy-cache'
  # - minage - don't check remote copy if the file is newer than this number of seconds
  # - enabled - is the cache enabled initially
  def initialize(dir: '/tmp/whimsy-cache',
        minage: 3000, # 50 mins
        enabled: true)
    if dir.start_with?('/')
      @dir = dir
    else
      @dir = File.join('/tmp/whimsy-cache', dir)
    end
    @enabled = enabled
    @minage = minage
    init_cache(@dir) if enabled
  end

  # enable the cache
  def enabled=(enabled)
    @enabled = enabled
    init_cache(@dir) if enabled
  end

  # gets the URL content
  #
  # Caches the response and returns that if unchanged or recent
  #
  # Returns:
  # - uri (after redirects)
  # - content
  # - status: nocache, recent, updated, missing or no last mod/etag
  def get(url)
    if not @enabled
      uri, res = fetch(url)
      return uri, res.body, 'nocache'
    end

    # Check the cache
    age, lastmod, uri, etag, data = read_cache(url)
    Wunderbar.debug "#{uri} #{age} LM=#{lastmod} ET=#{etag}"
    if age < minage
      return uri, data, 'recent' # we have a recent cache entry
    end

    # Try to do a conditional get
    if data and (lastmod or etag)
      cond = {}
      cond['If-Modified-Since'] = lastmod if lastmod
      # Allow for Apache Bug 45023
      cond['If-None-Match'] = etag.gsub(/-gzip"$/,'"') if etag
      uri, res = fetch(url, cond)
      if res.is_a?(Net::HTTPSuccess)
        write_cache(url, res)
        return uri, res.body, 'updated'
      elsif res.is_a?(Net::HTTPNotModified)
        path = makepath(url)
        mtime = Time.now
        File.utime(mtime, mtime, path) # show we checked the page
        return uri, data, 'unchanged'
      else
        return nil, res, 'error'
      end
    else
      uri, res = fetch(url)
      if res.is_a?(Net::HTTPSuccess)
        write_cache(url, res)
        return uri, res.body, data ? 'no last mod/etag' : 'cachemiss'
      else
        return nil, res, 'error'
      end
    end
  end

  private

  def init_cache(path)
    return if File.directory?(path) and File.writable?(path)
    begin
      FileUtils.mkdir_p path
      Wunderbar.info "Created the cache #{path}"
      raise Exception.new("Not writable") unless File.writable?(path)
    rescue Exception => e
      Wunderbar.warn "Could not create the cache #{path} - #{e}"
      @enabled = false
    end
  end

  # fetch uri, following redirects
  def fetch(uri, options={}, depth=1)
    if depth > 5
      raise IOError.new("Too many redirects (#{depth}) detected at #{uri}")
    end
    uri = URI.parse(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new(uri.request_uri)
      options.each do |k,v|
        request[k] = v
      end
      response = http.request(request)
      Wunderbar.debug "Headers: #{response.to_hash.inspect}"
      Wunderbar.debug response.code
      if response.code == '304' # Not modified
        return uri, response
      elsif response.code =~ /^3\d\d/ # assume redirect
        fetch response['location'], options, depth+1
      else
        return uri, response
      end
    end
  rescue Net::OpenTimeout
    # retry timeouts (essentially treat them as self redirects)
    raise if depth >= 5
    fetch(uri.to_s, options, depth+1)
  end

  # File cache contains last modified followed by the data
  # The file mod time can be used to skip any checks for recently updated files
  def write_cache(uri, res)
    path = makepath(uri)
    open path, 'wb' do |io|
      io.puts res['Last-Modified']
      io.puts uri
      io.puts res['Etag']
      io.write res.body
    end
  end

  # return age, last-modified, uri, data
  def read_cache(uri)
    path = makepath(uri)
    mtime = File.stat(path).mtime rescue nil
    last = nil
    data = nil
    uri = nil
    etag = nil
    if mtime
      open path, 'rb' do |io|
        last = io.gets.chomp
        uri = URI.parse(io.gets.chomp)
        etag = io.gets.chomp
        data = io.read
#       Fri, 12 May 2017 14:10:23 GMT
#       123456789012345678901234567890
        last = nil unless last.length > 25
      end
    end

    return Time.now - (mtime ? mtime : Time.new(0)), last, uri, etag, data
  end

  def makepath(uri)
    name = Digest::MD5.hexdigest uri.to_s
    File.join @dir, name
  end

end
