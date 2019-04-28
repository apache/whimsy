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

# parse and return the contents of the latest memapp-received file

# find latest memapp-received.txt file in the foundation/Meetings directory
meetings = ASF::SVN['Meetings']
received = Dir["#{meetings}/2*/memapp-received.txt"].sort.last.untaint

# extract contents
pattern = /^\w+\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(.*?)\s*\n/
if Date.today - Date.parse(received[/\d{8}/]) <= 32
  table = File.read(received).scan(pattern)
else
  table = []
end

# map contents to a hash
fields = %w(apply mail karma id name)
{received: table.map {|results| fields.zip(results).to_h}}
