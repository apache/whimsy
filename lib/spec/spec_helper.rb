$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
ASF::SVN['apmail_bin'] = File.expand_path('../test/svn/apmail_bin', __dir__)

unless defined?(SPEC_ROOT)
  SPEC_ROOT = File.join(File.dirname(__FILE__))
end

def fixture_path(*path)
  File.join SPEC_ROOT, 'fixtures', path
end
