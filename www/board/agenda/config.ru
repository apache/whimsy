require File.expand_path('../main.rb', __FILE__)

require 'whimsy/asf/rack'

# https://svn.apache.org/repos/infra/infrastructure/trunk/projects/whimsy/asf/rack.rb
use ASF::Auth::MembersAndOfficers do |env|
  # additionally authorize all invited guests
  agenda = dir('board_agenda_*.txt').sort.last
  Agenda.parse(agenda, :full)
  roll = Agenda[agenda][:parsed].find {|item| item['title'] == 'Roll Call'}
  roll['people'].keys.include? env['REMOTE_USER']
end

use ASF::HTTPS_workarounds

run Sinatra::Application
