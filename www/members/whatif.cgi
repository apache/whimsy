#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

require 'whimsy/asf/config'
require 'whimsy/asf/svn'

MEETINGS = ASF::SVN['Meetings']

Dir.chdir ASF::SVN['steve']
require "./whatif"
