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
# Render and edit a person's SpamAssassin score
#

class PersonSascore < Vue
  def render
    committer = @@person.state.committer

    _div.row data_edit: 'sascore' do
      _div.name 'SpamAssassin score'

      _div.value do

        if @@edit == :sascore

          _form method: 'post' do
            _input type: 'number', min: 0, max: 10, 
              name: 'sascore', value: committer.sascore
            _input type: 'submit', value: 'submit'
          end

        else

          _span committer.sascore

        end
      end
    end
  end
end
