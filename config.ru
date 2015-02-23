require File.expand_path('../main.rb', __FILE__)

require 'whimsy/asf/rack'

# https://svn.apache.org/repos/infra/infrastructure/trunk/projects/whimsy/asf/rack.rb
use ASF::Auth::MembersAndOfficers
use ASF::HTTPS_workarounds

run Sinatra::Application
