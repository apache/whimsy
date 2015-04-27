# common
require_relative 'router'
require_relative 'keyboard'
require_relative 'utils'

# General layout
require_relative 'layout/main'
require_relative 'layout/header'
require_relative 'layout/footer'

# Individual pages
require_relative 'pages/index'
require_relative 'pages/report'
require_relative 'pages/action-items'
require_relative 'pages/search'
require_relative 'pages/comments'
require_relative 'pages/help'
require_relative 'pages/shepherd'
require_relative 'pages/queue'
require_relative 'pages/backchannel'

# Button + forms
require_relative 'buttons/add-comment'
require_relative 'buttons/approve'
require_relative 'buttons/attend'
require_relative 'buttons/commit'
require_relative 'buttons/markseen'
require_relative 'buttons/post'
require_relative 'buttons/refresh'
require_relative 'buttons/showseen'
require_relative 'buttons/message'

# Common elements
require_relative 'elements/link'
require_relative 'elements/modal-dialog'
require_relative 'elements/text'

# Model
require_relative 'models/agenda'
require_relative 'models/jira'
require_relative 'models/pending'
