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
    ASF::SVN.svn_('update', File.join(tmpdir, File.basename(agenda_file)), _, {env: env})

    # copy the agenda to the minutes (produces better diff)
    ASF::SVN.svn_('cp',[File.join(tmpdir, File.basename(@agenda)),
                        File.join(tmpdir, File.basename(minutes_file))], _)

    @text
  end
end

drafts = Dir.chdir(FOUNDATION_BOARD) {Dir['board_minutes_*.txt'].sort}

drafts
