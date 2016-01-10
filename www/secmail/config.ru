require File.expand_path('../server.rb', __FILE__)

require 'whimsy/asf/rack'

use ASF::HTTPS_workarounds

run Sinatra::Application
