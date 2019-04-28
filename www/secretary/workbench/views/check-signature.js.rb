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
# Check signatures for validity using gpg on the server
#

class CheckSignature < Vue
  def initialize
    @signature = nil
    @checked = nil
  end

  def render
    if @signature
      _div.alert @alert, class: @flag
    end
  end

  def mounted()
    @signature = CheckSignature.find(@@selected, @@attachments)

    if @signature and @signature != @checked
      @flag = 'alert-info'
      @alert = 'checking signature'

      data = {
        message: window.parent.location.pathname,
        attachment: @@selected,
        signature: @signature
      }

      HTTP.post('../../actions/check-signature', data).then {|response|
        output = response.output + response.error

        if output.include? 'Good signature'
          @flag = 'alert-success'
        else
          @flag = 'alert-danger'
        end

        @alert = output
        @checked = @signature
      }.catch {|error|
        @alert = error
        @flag = 'alert-warning'
      }
    end
  end

  # find signature file that matches the selected attachment from the list
  # of attachments
  def self.find(selected, attachments)
    return unless selected

    # first look for a signature that matches this selected file
    signature = attachments.find {|attachment|
      attachment == selected + '.asc' or attachment == selected + '.sig'
    }

    # if no exact match, look closer at the other attachment if there
    # are exactly two attachments
    if not signature and attachments.length == 2
      signature = attachments.find {|attachment| attachment != selected}

      unless signature.end_with? '.asc' or signature.end_with? '.sig'
        signature = nil
      end
    end

    return signature
  end
end
