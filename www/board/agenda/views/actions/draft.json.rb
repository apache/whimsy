##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

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

drafts
