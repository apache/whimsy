#!/usr/bin/env ruby

# @(#) monthly tidy-up script

# Script to tidy up directories
#
# Deletes files older than 13 months from the following directories:
# - /srv/mail/board
# - /srv/mail/members
# - /srv/mail/secretary

require 'date'
require 'fileutils'

keep = (Date.today << 13).strftime('%Y%m')

Dir.chdir '/srv/mail'

Dir[*%w(board/20* members/20* secretary/20*)].each do |dir|
  if File.basename(dir) < keep
    begin
      FileUtils.rm_r dir, :verbose => true
    rescue => e
      puts e
    end
  end
end
