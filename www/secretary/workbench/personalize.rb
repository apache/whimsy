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
# Per user email personalizations
#

class Wunderbar::JsonBuilder
  def _personalize_email(user)
    if user == 'clr'

      @from = 'Craig L Russell <clr@apache.org>'
      @sig = %{
        -- Craig L Russell
        Assistant Secretary, Apache Software Foundation
      }

    elsif user == 'mattsicker'

      @from = 'Matt Sicker <secretary@apache.org>'
      @sig = %{
        -- Matt Sicker
        Secretary, Apache Software Foundation
      }

    else

      person = ASF::Person.find(user)

      @from = "#{person.public_name} <#{user}@apache.org>".untaint
      @sig = %{
        -- #{person.public_name}
        Apache Software Foundation Secretarial Team
      }

    end

    # strip extraneous whitespace from signature
    @sig = @sig.gsub(/^\s*/, '').strip
  end
end
