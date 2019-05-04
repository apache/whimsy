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
# Tempfile in Ruby 2.3.0 has the unfortunate behavior of returning
# an unsafe path and even blowing up when unlink is called in a $SAFE
# environment.  This avoids those two problems, while forwarding all all other
# method calls.
#

require 'tempfile'

class SafeTempFile
  def initialize *args
    args << {} unless args.last.instance_of? Hash
    args.last[:encoding] = Encoding::BINARY
    @tempfile = Tempfile.new *args
  end

  def path
    @tempfile.path.untaint
  end

  def unlink
    File.unlink path
  end

  def method_missing symbol, *args
    @tempfile.send symbol, *args
  end
end
