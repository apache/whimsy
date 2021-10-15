require File.expand_path('../main.rb', __FILE__)

require 'whimsy/asf/rack'

use ASF::HTTPS_workarounds
use ASF::ETAG_Deflator_workaround
use ASF::Auth::Committers
use ASF::DocumentRoot
use Rack::Deflater

run Sinatra::Application
