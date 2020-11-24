#!/usr/bin/env ruby
#
# Convert "new format" raw_board_votes.json into "old format"
# board_nominations.ini and raw_board_votes.txt for use by the whatif tool.
#

require 'json'

raw_file = Dir["/srv/svn/Meetings/*/raw_board_votes.json"].max
raw_votes = JSON.parse(IO.read(raw_file))
txt_file = raw_file.sub('.json', '.txt')
ini_file = File.dirname(raw_file) + '/board_nominations.ini'

votes = ''
raw_votes['votes'].sort_by {|_key, data| data['timestamp']}.each do |key, data|
  time = Time.at(data['timestamp']).gmtime.strftime("%Y/%m/%d %H:%M:%S")
  vote = data['vote'].split(' ').map {|vote| vote[-1]}.join.downcase
  votes += "[#{time}] #{key[0..31]} #{vote}\n"
end

if !File.exist?(txt_file) or votes != IO.read(txt_file)
  IO.write(txt_file, votes)
end

letter = 'a'
ini =  "[nominees]\n"
raw_votes['issue']['candidates'].each do |candidate|
  ini += "#{letter}: #{candidate['name']}\n"
  letter.succ!
end

if !File.exist?(ini_file) or ini != IO.read(ini_file)
  IO.write(ini_file, ini)
end

puts votes
puts
puts ini
