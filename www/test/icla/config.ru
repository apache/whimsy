require File.expand_path('../main.rb', __FILE__)

require 'whimsy/asf/rack'

# https://svn.apache.org/repos/infra/infrastructure/trunk/projects/whimsy/asf/rack.rb
use ASF::Auth::Committers
use ASF::HTTPS_workarounds
use ASF::DocumentRoot

run Sinatra::Application
