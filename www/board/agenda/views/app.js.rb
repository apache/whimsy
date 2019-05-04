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

# config
require_relative 'vue-config'
require_relative 'event-bus'

# common
require_relative 'router'
require_relative 'keyboard'
require_relative 'touch'
require_relative 'utils'

# General layout
require_relative 'layout/main'
require_relative 'layout/header'
require_relative 'layout/footer'

# Individual pages
require_relative 'pages/adjournment'
require_relative 'pages/bootstrap'
require_relative 'pages/index'
require_relative 'pages/report'
require_relative 'pages/action-items'
require_relative 'pages/search'
require_relative 'pages/comments'
require_relative 'pages/help'
require_relative 'pages/secrets'
require_relative 'pages/shepherd'
require_relative 'pages/queue'
require_relative 'pages/flagged'
require_relative 'pages/rejected'
require_relative 'pages/missing'
require_relative 'pages/backchannel'
require_relative 'pages/roll-call'
require_relative 'pages/select-actions'
require_relative 'pages/feedback'
require_relative 'pages/cache'
require_relative 'pages/fy23'

# Button + forms
require_relative 'buttons/add-comment'
require_relative 'buttons/add-minutes'
require_relative 'buttons/approve'
require_relative 'buttons/attend'
require_relative 'buttons/commit'
require_relative 'buttons/draft-minutes'
require_relative 'buttons/markseen'
require_relative 'buttons/message'
require_relative 'buttons/offline'
require_relative 'buttons/post'
require_relative 'buttons/post-actions'
require_relative 'buttons/publish-minutes'
require_relative 'buttons/reminders'
require_relative 'buttons/refresh'
require_relative 'buttons/showseen'
require_relative 'buttons/summary'
require_relative 'buttons/timestamp'
require_relative 'buttons/vote'
require_relative 'buttons/email'
require_relative 'buttons/install'

# Common elements
require_relative 'elements/additional-info'
require_relative 'elements/link'
require_relative 'elements/modal-dialog'
require_relative 'elements/text'
require_relative 'elements/info'
require_relative 'elements/pns'

# Model
require_relative 'models/events'
require_relative 'models/pagecache'
require_relative 'models/agenda'
require_relative 'models/minutes'
require_relative 'models/chat'
require_relative 'models/jira'
require_relative 'models/pending'
require_relative 'models/responses'
require_relative 'models/user'
require_relative 'models/posted'
require_relative 'models/comments'
require_relative 'models/jsonstorage'
