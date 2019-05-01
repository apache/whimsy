#!/usr/bin/env ruby

# @(#) monthly tidy-up script

# Script to tidy up directories
#
# Deletes files older than 13 months from the following directories:
# - /srv/mail/board
# - /srv/mail/members

require 'date'
require 'fileutils'

keep = (Date.today << 13).strftime('%Y%m')

MAIL = '/srv/mail'

Dir["#{MAIL}/board/20*", "#{MAIL}/members/20*"].each do |dir|
  if File.basename(dir) < keep
    puts "Deleting #{dir}"
    FileUtils.rm_rf dir
  end
end
