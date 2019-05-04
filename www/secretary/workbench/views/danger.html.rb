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

_html do
  _h1.bg_danger 'Potentially Dangerous Content'

  _table.table.table_bordered do
    _tbody do
      @part.headers.each do |name, value|
        next if name == :mime
        _tr do
          _td name.to_s
          if name == :name
            _td do
              _a value, href: "../#{value}"
            end
          else
            _td value
          end
        end
      end
    end
  end
end
