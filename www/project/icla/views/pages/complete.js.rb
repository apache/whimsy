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

class Complete < Vue
  def render
    _p %{
      At this point, the demo is complete.  If this were a real application:
    }

    _ul do
      _li {_p 'An file would have been committed to SVN.'}

      _li do
        _p 'Commit message would include the following IP address information:'
        _pre FormData.ipaddr
      end

      _li {_p 'An email would have been sent to the PMC.'}

      if FormData.apacheid
        _li {_p 'An new account request would have been submitted.'}
      end
    end
  end
end
