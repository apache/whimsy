#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

require 'whimsy/asf/config'
require 'whimsy/asf/svn'

MEETINGS = ASF::SVN['private/foundation/Meetings']

Dir.chdir ASF::SVN['asf/steve/trunk']
require "./whatif"
