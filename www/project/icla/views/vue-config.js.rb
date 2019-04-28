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

# Filter out "data property already declared as a prop" warnings
Vue.config.warnHandler = proc do |msg, vm, trace|
  return if msg =~ /^The data property "\w+" is already declared as a prop\./
  console.error "[Vue warn]: " + msg + trace if defined? console
end

# reraise uncapturable errors asynchronously to enable easier debugging
Vue.config.errorHandler = proc do |err, vm, info|
  setTimeout(0) { raise err }
end
