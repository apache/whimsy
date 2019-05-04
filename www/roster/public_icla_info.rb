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

# Extract public data from iclas.txt

require_relative 'public_json_common'

# gather icla info
ids = {}
noid = []

ASF::ICLA.each do |entry|
  if entry.id == 'notinavail'
    noid << entry.name
  else
    ids[entry.id] = entry.name
  end
end

# 2 files specified - split id/noid into separate files
if ARGV.length == 2

  info_id = {
    last_updated: ASF::ICLA.svn_change,
    committers: Hash[ids.sort]
  }
  public_json_output_file(info_id, ARGV.shift)
  
  info_noid = {
    last_updated: ASF::ICLA.svn_change,
    non_committers: noid
  }
  public_json_output_file(info_noid, ARGV.shift)

else # combined (original) output file

  info = {
    last_updated: ASF::ICLA.svn_change,
    committers: Hash[ids.sort],
    non_committers: noid # do not sort because the input is already sorted by surname
  }

  public_json_output(info) # original full output

end
