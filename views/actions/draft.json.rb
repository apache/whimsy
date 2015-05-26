#
# commit draft minutes to SVN
#

agenda_file = "#{FOUNDATION_BOARD}/#{@agenda}"
agenda_file.untaint if @agenda =~ /^board_agenda_\d+_\d+_\d+.txt$/
minutes_file = agenda_file.sub('_agenda', '_minutes')

unless File.exist? minutes_file
  `svn cp #{agenda_file} #{minutes_file}` if File.exist? agenda_file

  File.write(minutes_file, @text)

  `svn add #{minutes_file}` unless File.exist? agenda_file

  commit = ['svn', 'commit', '-m', @message, minutes_file,
    '--no-auth-cache', '--non-interactive']

  if env.password
    commit += ['--username', env.user, '--password', env.password]
  end

  require 'shellwords'
  output = `#{Shellwords.join(commit).untaint} 2>&1`
  if $?.exitstatus != 0
    _.error (output.empty? ? 'svn commit failed' : output)
    raise Exception.new('svn commit failed')
  end
end

drafts = Dir.chdir(FOUNDATION_BOARD) {Dir['board_minutes_*.txt'].sort}

Events.post type: :server, drafts: drafts

drafts
