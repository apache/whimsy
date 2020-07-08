$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'

SAMPLE_SVN_NAME = 'minutes' # name of checkout of public SVN dir
SAMPLE_SVN_URL_RE = %r{https://.+/minutes}

# Override with test data if there is no checkout available (allows local use)
if ENV['RAKE_TEST'] == 'TRUE' or not (ASF::SVN.find('apmail_bin') and ASF::SVN.find('board'))
  TEST_DATA = true # Test data is smaller so some tests need adjusting
  puts "Overriding data directories"
  ASF::SVN['apmail_bin'] = File.expand_path('../test/svn/apmail_bin', __dir__)
  ASF::SVN['board'] = File.expand_path('../test/svn/board', __dir__)
  ASF::SVN[SAMPLE_SVN_NAME] = File.expand_path('../test/svn/minutes', __dir__)
  ASF::Config[:subscriptions] = File.expand_path('../test/subscriptions', __dir__)
else
  TEST_DATA = false
end

def set_root
  ASF::Config.setroot File.expand_path("../test", __dir__)
end

def set_svn(name)
  ASF::SVN[name] = File.expand_path("../test/svn/#{name}", __dir__)
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

# run _json code and return [return code, target]
def _json(&block)
  # TODO: This is a bit of a hack
  js = Wunderbar::JsonBuilder.new(Struct.new(:params).new({}))
  js.log_level = :fatal
  rc = nil
  begin
    rc = yield js
  rescue Exception => e
    js._exception(e)
  end
  [rc, js.target?]
end

# for testing code that needs credentials
class ENV_
  def initialize(user=nil, pass=nil)
    @user = user || 'user'
    @pass = pass || 'pass'
  end
  def user
    @user
  end
  def password
    @pass
  end
end
