#!/usr/bin/env ruby
$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf/config'
require 'whimsy/asf/svn'

MEETINGS = ASF::SVN['Meetings']

Dir.chdir ASF::SVN['steve']
require "./whatif"
