#
# When mail comes in indicating that foundation/board was updated,
# update the local working copy.
#

require 'mail'

mail = Mail.new(STDIN.read)

LOG = '/srv/whimsy/www/logs/svn-update'

if mail.subject =~ %r{^board: r\d+ -( in)? /foundation/board}

  # prevent concurrent updates being performed by the cron job
  File.open(LOG, File::RDWR|File::CREAT, 0644) do |log|
    log.flock(File::LOCK_EX)

    Dir.chdir '/srv/svn/foundation_board' do
      `svn cleanup`
      `svn update`
    end
  end

end

