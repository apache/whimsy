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
# Action items.  Link to PMC reports when possible, highlight missing
# action item status updates.
#

class SelectActions < Vue
  def self.buttons()
    return [{button: PostActions}]
  end

  def initialize
    @list = []
    @names = []
  end

  def render
    _h3 'Post Action Items'

    _p.alert_info 'Action Items have yet to be posted. '+
      'Unselect the ones below that have been completed. ' +
      'Click on the "post actions" button when done.'

    _pre.report do
      @list.each do |action|
        _CandidateAction action: action, names: @names
      end
    end
  end

  def mounted()
    retrieve 'potential-actions', :json do |response|
      if response
        @list = response.actions
        @names = response.names
        EventBus.emit :potential_actions, @list
      end
    end
  end
end

class CandidateAction < Vue
  def render
    _input type: 'checkbox', checked: !@@action.complete,
      onClick:-> {@@action.complete = !@@action.complete}
    _span " "
    _span @@action.owner
    _span ": "
    _span @@action.text
    _span "\n      [ #{@@action.pmc} #{@@action.date} ]\n      "
    if @@action.status
      _Text raw: "Status: #{@@action.status}\n", filters: [hotlink]
    end
    _span "\n"
  end
end
