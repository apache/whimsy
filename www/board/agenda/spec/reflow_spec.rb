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
# component tests for client side forms
#

require_relative 'spec_helper'
require_relative 'vue_server'

describe "reflow", type: :feature, server: :vue do
  #
  # Comment form
  #
  describe "incubator rules" do
    it "handles ordered lists" do
      on_vue_server do
        class TestReflow < Vue
          def render
            _ Flow.text("1. a\n2. b")
          end
        end

        Vue.renderResponse(TestReflow, response)
      end

      expect(page.body).to eq "1. a\n2. b"
    end

    it "handles questions and colons" do
      on_vue_server do
        class TestReflow < Vue
          def render
            _ Flow.text("a?\nb:\nc", '', true)
          end
        end

        Vue.renderResponse(TestReflow, response)
      end

      expect(page.body).to eq "a?\nb:\nc"
    end

    it "leaves long URLs alone" do
      @line = "[7] http://example.com" + "/foobar" * 12

      on_vue_server do
        line = @line

        class TestReflow < Vue
          def render
            _ Flow.text(line)
          end
        end

        Vue.renderResponse(TestReflow, response)
      end

      expect(page.body).to eq @line
    end
  end
end
