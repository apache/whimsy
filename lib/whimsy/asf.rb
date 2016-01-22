require File.expand_path('../asf/config', __FILE__)
require File.expand_path('../asf/committee', __FILE__)
require File.expand_path('../asf/ldap', __FILE__)
require File.expand_path('../asf/mail', __FILE__)
require File.expand_path('../asf/svn', __FILE__)
require File.expand_path('../asf/watch', __FILE__)
require File.expand_path('../asf/nominees', __FILE__)
require File.expand_path('../asf/icla', __FILE__)
require File.expand_path('../asf/auth', __FILE__)
require File.expand_path('../asf/member', __FILE__)
require File.expand_path('../asf/site', __FILE__)

module ASF
  def self.library_mtime
    parent_dir = File.dirname(File.expand_path(__FILE__))
    sources = Dir.glob("#{parent_dir}/**/*")
    times = sources.map {|source| File.mtime(source)}
    times.max.gmtime
  end
  def self.library_gitinfo
    return @info if @info
    @info = `git show --format="%h  %cI"  -s HEAD`.chomp
  end
end
