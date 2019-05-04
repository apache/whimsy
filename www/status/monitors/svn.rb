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
# Monitor status of svn updates
#
=begin
Sample input:
---- cut here ---

/srv/svn/Bills
Updating '.':
At revision 67610.

/srv/svn/site-root
Updating '.':
U    index.html
Updated to revision 1797393.

/srv/svn/site-root
A    site-root/extpaths.txt
 U   site-root
Checked out revision 1797381.

/x1/srv/svn/personnel-duties
Updating '.':
svn: E175002: Unexpected HTTP status 400 'Bad Request' on '/repos/private/!svn/rvr/76960/foundation/officers/personnel-duties'

/x1/srv/svn/personnel-duties
#!: failed!
#!: Updating '.':
#!: svn: E175002: Unexpected HTTP status 400 'Bad Request' on '/repos/private/!svn/rvr/76960/foundation/officers/personnel-duties'
#!: will retry in 10 seconds
Updating '.':
svn: E175002: Unexpected HTTP status 400 'Bad Request' on '/repos/private/!svn/rvr/76960/foundation/officers/personnel-duties'
Updated to revision 1797393.

---- cut here ---

Output status level can be:
Success - workspace is up to date
Info - one or more files updated
Warning - partial response
Danger - unexpected text in log file

=end

require 'fileutils'

# Match revision messages
REV_RE = %r{^(Checked out|Updated to|At) revision \d+\.$}

def Monitor.svn(previous_status)
  logdir = File.expand_path('../../../logs', __FILE__)
  archive = File.join(logdir,'archive')
  FileUtils.mkdir(archive) unless File.directory?(archive)

  # read cron log
  log = File.expand_path('../../../logs/svn-update', __FILE__)
  fdata = File.open(log) {|file| file.flock(File::LOCK_EX); file.read}
  updates = fdata.split(%r{\n(?:/\w+)*/srv/svn/})[1..-1]

  status = {}
  seen_level = {}

  # extract status for each repository
  updates.each do |update|
    level = 'success'
    title = nil
    data = revision = update[REV_RE] # data === String

    lines = update.split("\n")
    repository = lines.shift.to_sym

    lines.reject! do |line| 
      line == "Updating '.':" or
      # must agree with Rakefile/PREFIX
      line.start_with?('#!: ') or
      line =~ REV_RE
    end

    unless lines.empty?
      level = 'info'
      data = lines.dup # array
    end

    lines.reject! {|line| line =~ /^([ADU] |[ U]U)   /}

    if lines.empty?
      if not data
        title = "partial response"
        level = 'warning'
        seen_level[level] = true
      elsif String  === data # only saw revision message
        title = "No files updated"
      elsif data.length == 1
        title = "1 file updated"
      else
        title = "#{data.length} files updated"
      end

      data << revision if revision and data.instance_of? Array
    else
      level = 'danger'
      data = lines.dup
      seen_level[level] = true
    end

    status[repository] = {level: level, data: data, href: '../logs/svn-update'}
    status[repository][:title] = title if title
  end

  # save as the highest level seen
  %w{danger warning}.each do |lvl|
    if seen_level[lvl]
      # Save a copy of the log; append the severity so can track more problems
      file = File.basename(log)
      FileUtils.copy log, File.join(archive, file + '.' + lvl), preserve: true
      break
    end
  end
  
  {data: status}
end

# for debugging purposes
if __FILE__ == $0
  require_relative 'unit_test'
  runtest('svn') # must agree with method name above
end
