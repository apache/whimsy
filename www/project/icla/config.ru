require File.expand_path('../main.rb', __FILE__)

require 'whimsy/asf/rack'

use ASF::Auth::Committers
use ASF::HTTPS_workarounds
use ASF::DocumentRoot

run Sinatra::Application
