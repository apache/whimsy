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
# Convert markdown to html
#

class Markdown < Vue
  def render
    _span domPropsInnerHTML: html
  end

  def html
    # trim leading and trailing spaces
    text = @@text.sub(/^\s*\n/, '').sub(/\s+$/, '')

    # normalize indentation
    spaces = new RegExp('^ *\S', 'mg');
    match = regexp.exec(text)
    if match
      indent = match[0].length - 1
      while (match = regexp.exec(text))
        indent = match[0].length - 1 if indent >= match[0].length
      end

      if indent > 0
        spaces = Array.new(indent+1).join(' ')
        text = text.replace(new Regexp("^#{spaces}", 'g'), '')
      end
    end

    # convert markdown to text
    markd(text)
  end
end
