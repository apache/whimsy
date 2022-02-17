#  Licensed to the Apache Software Foundation (ASF) under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# Use relative paths for CI such as Travis
lib = File.expand_path('..', __dir__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include? lib

require 'whimsy/asf'
require 'whimsy/asf/config' # must be loaded before updating config

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
  ASF::SVN['incubator-podlings'] = File.expand_path('../test/svn/incubator-podlings', __dir__)
else
  TEST_DATA = false
end

def set_svnroot # ensure can access svn directory listing files
  ASF::Config.setsvnroot File.expand_path("../test/svn/*", __dir__)
end

def set_cache(restore=nil) # ensure can access test version of iclas.txt
  config = ASF::Config.instance_variable_get(:@config)
  original = config[:cache]
  if restore
    config[:cache] = restore
  else
    source = File.expand_path("../test/svn/", __dir__)
    FileUtils.touch File.join(source,'iclas.txt') # ensure it is marked as up-to-date
    config[:cache] = source
  end
  return original
end

def set_svn(name)
  ASF::SVN[name] = File.expand_path(File.join("..", "test", "svn", name), __dir__)
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
