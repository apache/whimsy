$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
# Override with test data if there is no checkout available (allows local use)
unless ASF::SVN.find('apmail_bin')
  ASF::SVN['apmail_bin'] = File.expand_path('../test/svn/apmail_bin', __dir__)
end

unless defined?(SPEC_ROOT)
  SPEC_ROOT = File.join(File.dirname(__FILE__))
end

def fixture_path(*path)
  File.join SPEC_ROOT, 'fixtures', path
end
