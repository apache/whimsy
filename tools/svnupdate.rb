#
# When mail comes in indicating that a repository was updated,
# update the local working copy.
#

require 'mail'

File.umask(0002)

STDIN.binmode
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

elsif mail.subject =~ %r{^committers: r\d+ -( in)? /committers/board}

  # prevent concurrent updates being performed by the cron job
  File.open(LOG, File::RDWR|File::CREAT, 0644) do |log|
    log.flock(File::LOCK_EX)

    Dir.chdir '/srv/svn/board' do
      `svn cleanup`
      `svn update`
    end
  end

elsif mail.subject =~ %r{^bills: r\d+ -( in)? /financials/Bills}

  # prevent concurrent updates being performed by the cron job
  File.open(LOG, File::RDWR|File::CREAT, 0644) do |log|
    log.flock(File::LOCK_EX)

    Dir.chdir '/srv/svn/Bills' do
      `svn cleanup`
      `svn update`
    end
  end

end

