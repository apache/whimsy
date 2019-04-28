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
# Replacement for 'a' element which handles clicks events that can be
# processed locally by calling Main.navigate.
#

class Link < Vue
  def render
    Vue.createElement(element, options, @@text)
  end

  def element
    if @@href
      'a'
    else
      'span'
    end
  end

  def options
    result = {attrs: {}}

    if @@href
      result.attrs.href = @@href.gsub(%r{(^|/)\w+/\.\.(/|$)}, '$1')
    end

    result.attrs.rel = @@rel if @@rel
    result.attrs.id = @@id if @@id

    result.on = {click: self.click}

    result 
  end

  def click(event)
    return if event.ctrlKey or event.shiftKey or event.metaKey

    href = event.target.getAttribute('href')

    if href =~ %r{^(\.|cache/.*|(flagged/|(shepherd/)?(queue/)?)[-\w]+)$}
      event.stopPropagation()
      event.preventDefault()
      Main.navigate href
      return false
    end
  end
end
