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

require 'mail'

Mail.defaults do
  delivery_method :test

  if $USER == 'clr'

    @from = 'Craig L Russell <clr@apache.org>'
    @sig = %{
      -- Craig L Russell
      Secretary, Apache Software Foundation
    }

  elsif $USER == 'jcarman'

    @from = 'James Carman <jcarman@apache.org>'
    @sig = %{
      -- James Carman
      Assistant Secretary, Apache Software Foundation
    }

  elsif $USER == 'rubys'

    @from = 'Sam Ruby <rubys@apache.org>'
    @sig = %{
      -- Sam Ruby
      Apache Software Foundation Secretarial Team
    }

  elsif $USER == 'sanders'

    @from = 'Scott Sander <sanders@apache.org>'
    @sig = %{
      -- Scott Sander
      Apache Software Foundation Secretarial Team
    }

  elsif $USER == 'mnour'

    @from = 'Mohammad Nour El-Din <mnour@apache.org>'
    @sig = %{
      -- Mohammad Nour El-Din
      Apache Software Foundation Secretarial Team
    }
  end
end


