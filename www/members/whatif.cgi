#!/usr/bin/env ruby
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf/config'
require 'whimsy/asf/svn'
require 'wunderbar'

MEETINGS = ASF::SVN['Meetings']

# This is a hack:
# STeVe has moved to Git, however whatif.py no longer works in that environment due to changes in stv_tool.py
# So for the time being, continue to use the old code in SVN
Dir.chdir ASF::SVN['steve']
# However, whatif.rb no longer works with the current version of Ruby
# See: https://github.com/apache/whimsy/issues/257
# The file below is a corrected copy
# 
require '/srv/whimsy/tools/whatif'
