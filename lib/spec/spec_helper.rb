$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
# Override with test data if there is no checkout available (allows local use)
if ENV['RAKE_TEST'] == 'TRUE' or not ASF::SVN.find('apmail_bin')
  TEST_DATA = true # Test data is smaller so some tests need adjusting
  puts "Overriding data directories"
  ASF::SVN['apmail_bin'] = File.expand_path('../test/svn/apmail_bin', __dir__)
  ASF::Config[:subscriptions] = File.expand_path('../test/subscriptions', __dir__)
else
  TEST_DATA = false
end

if TEST_DATA
  puts "TEST_DATA=#{TEST_DATA}"
else
  puts "TEST_DATA=#{TEST_DATA} (set RAKE_TEST=TRUE to override)"
end

unless defined?(SPEC_ROOT)
  SPEC_ROOT = File.join(File.dirname(__FILE__))
end

def fixture_path(*path)
  File.join SPEC_ROOT, 'fixtures', path
end
