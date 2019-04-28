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
# Main class, nearly all scaffolding for demo purposes
#

class Main < Vue
  def initialize
    @view = Invite
  end

  def render
    _main do
      _h1 'Demo: Discuss, Vote, and Invite'

      Vue.createElement(@view)
    end
  end

  # save data on first load
  def created()
    # @@data is set up by app.html.rb
    Server.data = @@data
  end

  def mounted()
    # @@view is set up by app.html.rb
    # set view based on properties
    if @@view == 'interview'
      @view = Interview
    elsif @@view == 'discuss'
      @view = Discuss
    elsif @@view == 'vote'
      @view = Vote
    else
      @view = Invite
    end

    # export navigation method on the client
    Main.navigate = self.navigate
  end

  # Another navigation means in support of the demo
  def navigate(view)
    @view = view
    window.scrollTo(0, 0)
  end
end
