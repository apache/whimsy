require_relative 'asf/config'
require_relative 'asf/committee'
require_relative 'asf/ldap'
require_relative 'asf/mail'
require_relative 'asf/svn'
require_relative 'asf/watch'
require_relative 'asf/nominees'
require_relative 'asf/icla'
require_relative 'asf/auth'
require_relative 'asf/member'
require_relative 'asf/site'

module ASF
  def self.library_mtime
    parent_dir = File.dirname(File.expand_path(__FILE__))
    sources = Dir.glob("#{parent_dir}/**/*")
    times = sources.map {|source| File.mtime(source)}
    times.max.gmtime
  end
  def self.library_gitinfo
    return @info if @info
    @info = `git show --format="%h  %ci"  -s HEAD`.chomp
  end
end
