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
# Encapsulate memory of selected item and delete stack
#

class Status
  def self.secmail
    return {} if not defined? sessionStorage
    JSON.parse(sessionStorage.getItem('secmail') || '{}')
  end

  def self.selected
    Status.secmail.selected
  end

  def self.selected=(value)
    secmail = Status.secmail
    secmail.selected=value
    sessionStorage.setItem('secmail', JSON.stringify(secmail))
  end

  def self.undoStack
    secmail = Status.secmail
    return secmail.undoStack || []
  end

  def self.pushDeleted(value)
    value = value[/\w+\/\w+\/?$/].sub(/\/?$/, '/')
    secmail = Status.secmail
    secmail.undoStack ||= []
    secmail.undoStack << value
    sessionStorage.setItem('secmail', JSON.stringify(secmail))
  end

  def self.popStack()
    secmail = Status.secmail
    secmail.undoStack ||= []
    item = secmail.undoStack.pop()
    sessionStorage.setItem('secmail', JSON.stringify(secmail))
    return item
  end
end
