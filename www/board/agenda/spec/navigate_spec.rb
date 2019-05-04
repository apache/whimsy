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
# Keyboard navigation and back button
#

require_relative 'spec_helper'

feature 'navigation', js: true do
  it "should navigate to the Cocoon report and back" do
    skip "headless browser test not run on Travis" if ENV['TRAVIS']

    visit '/2015-02-18/Clerezza'
    expect(page).to have_selector '.navbar-fixed-top.reviewed .navbar-brand', 
      text: 'Clerezza'

    # Right button should advance to Cocoon report
    find('body').native.send_keys(:right)
    expect(page).to have_selector '.navbar-fixed-top.reviewed .navbar-brand', 
      text: 'Cocoon'
    expect(page).to have_selector 'pre', 
      text: /needing board attention:\s*nothing/
    expect(page).to have_selector '.backlink[href="Clerezza"]', 
     text: 'Clerezza'
    expect(page).to have_selector '.nextlink[href="Community-Development"]', 
     text: 'Community Development'

    # Back button should return to Clerezza
    page.evaluate_script('window.history.back()')
    expect(page).to have_selector '.navbar-fixed-top.reviewed .navbar-brand', 
      text: 'Clerezza'
    expect(page).to have_selector 'pre', 
      text: /no issues requiring board attention/
    expect(page).to have_selector '.backlink[href="Chukwa"]', text: 'Chukwa'
    expect(page).to have_selector '.nextlink[href="Cocoon"]', text: 'Cocoon'
  end
end
