#
# commit draft minutes to SVN
#

agenda_file = "#{FOUNDATION_BOARD}/#{@agenda}"
agenda_file.untaint if @agenda =~ /^board_agenda_\d+_\d+_\d+.txt$/
minutes_file = agenda_file.sub('_agenda', '_minutes')

ASF::SVN.update minutes_file, @message, env, _ do |tmpdir, old_contents|
  if old_contents and not old_contents.empty?
    old_contents
  else
    # retrieve the agenda on which these minutes are based
    _.system ['svn', 'update',
      ['--username', env.user, '--password', env.password],
      "#{tmpdir}/#{File.basename agenda_file}"]

    # copy the agenda to the minutes (produces better diff)
    _.system ['svn', 'cp', "#{tmpdir}/#{@agenda}",
      "#{tmpdir}/#{File.basename minutes_file}"]

    @text
  end
end

drafts = Dir.chdir(FOUNDATION_BOARD) {Dir['board_minutes_*.txt'].sort}

IPC.post type: :server, drafts: drafts

drafts
