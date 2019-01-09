require File.expand_path('../server.rb', __FILE__)

require 'whimsy/asf/rack'

use ASF::HTTPS_workarounds
use ASF::Auth::MembersAndOfficers # change this to Committers later
use ASF::AutoGC

use ASF::DocumentRoot

run Sinatra::Application
