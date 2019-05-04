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
# Determine status of podling name
#

class PodlingNameSearch < Vue
  props [:item]

  def render
    _span.pns title: 'podling name search' do
      if Server.podlingnamesearch
        if not @results
          _abbr "\u2718", title: 'No PODLINGNAMESEARCH found'
        elsif @results.resolution == 'Fixed'
          _a "\u2714", href: 'https://issues.apache.org/jira/browse/' +
            @results.issue
        else
          _a "\uFE56", href: 'https://issues.apache.org/jira/browse/' +
            @results.issue
        end
      end
    end
  end

  # initial mount: fetch podlingnamesearch data unless already downloaded
  def mounted()
    if Server.podlingnamesearch
      self.check($props)
    else
      retrieve 'podlingnamesearch', :json do |results|
        Server.podlingnamesearch = results
        self.check($props)
      end
    end
  end

  # lookup name in the establish resolution against the podlingnamesearches
  def check(props)
    @results = nil
    name = props.item.title[/Establish (.*)/, 1]

    # if full title contains a name in parenthesis, check for that name too
    altname = props.item.fulltitle[/\((.*?)\)/, 1]

    if name and Server.podlingnamesearch
      for podling in Server.podlingnamesearch
        if name == podling
          @results = Server.podlingnamesearch[name]
        elsif altname == podling
          @results = Server.podlingnamesearch[altname]
        end
      end
    end

    Vue.forceUpdate()
  end
end
