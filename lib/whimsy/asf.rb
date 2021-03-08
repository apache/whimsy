require_relative 'asf/config'
require_relative 'asf/committee'
require_relative 'asf/ldap'
require_relative 'asf/mail'
require_relative 'asf/svn'
require_relative 'asf/git'
require_relative 'asf/watch'
require_relative 'asf/nominees'
require_relative 'asf/icla'
require_relative 'asf/documents'
require_relative 'asf/auth'
require_relative 'asf/member'
require_relative 'asf/petri'
require_relative 'asf/podling'
require_relative 'asf/person'
require_relative 'asf/themes'
require_relative 'asf/site-img'

#
# The ASF module contains a set of classes which encapsulate access to a number
# of data sources such as LDAP, ICLAs, auth lists, etc. This code originally
# was developed as a part of separate tools and was later refactored out into a
# common library. Some of the older tools don't fully make use of this
# refactoring.
#

module ASF
  # Last modified time of any file in the entire source tree.
  def self.library_mtime
    parent_dir = File.dirname(File.expand_path(__FILE__))
    sources = Dir.glob("#{parent_dir}/**/*")
    times = sources.map {|source| File.mtime(source)}
    times.max.gmtime
  end

  # Last commit in this clone, and the date and time of that commit.
  def self.library_gitinfo
    return @info if @info
    @info = `git show --format="%h  %ci"  -s HEAD`.strip
  end
end
