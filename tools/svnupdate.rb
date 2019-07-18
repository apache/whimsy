#
# When mail comes in indicating that a repository was updated,
# update the local working copy.
#

require 'mail'

File.umask(0002)

STDIN.binmode
mail = Mail.new(STDIN.read)

# This must agree with the file used by the svnupdate cron job
LOG = '/srv/whimsy/www/logs/svn-update'

# More testing
LOGTMP = '/srv/whimsy/www/logs/svn-update.tmp'
$stderr.reopen(File.new(LOGTMP,'at'))
$stdout.reopen(File.new(LOGTMP,'at'))

def update(dir)
  # prevent concurrent updates being performed by the cron job
  File.open(LOG, File::RDWR|File::CREAT, 0644) do |log|
    log.flock(File::LOCK_EX)

    puts "#{Time.now} Updating #{dir}" # Temporary test
    Dir.chdir dir do
      `svn cleanup`
      `svn update`
    end
  end
end

if mail.subject =~ %r{^board: r\d+ -( in)? /foundation/board} # board-commits@

  puts "Matched board" # test
  # prevent concurrent updates being performed by the cron job
  File.open(LOG, File::RDWR|File::CREAT, 0644) do |log|
    log.flock(File::LOCK_EX)

    Dir.chdir '/srv/svn/foundation_board' do
      `svn cleanup`
      `svn update`
    end
  end

elsif mail.subject =~ %r{^foundation: r\d+ -( in)? /foundation} # foundation-commits@
  # includes members.txt
  update '/srv/svn/foundation'

elsif mail.subject =~ %r{^committers: r\d+ -( in)? /committers/board} # committers-cvs@

  # prevent concurrent updates being performed by the cron job
  File.open(LOG, File::RDWR|File::CREAT, 0644) do |log|
    log.flock(File::LOCK_EX)

    Dir.chdir '/srv/svn/board' do
      `svn cleanup`
      `svn update`
    end
  end

elsif mail.subject =~ %r{^bills: r\d+ -( in)? /financials/Bills} # operations@

  # prevent concurrent updates being performed by the cron job
  File.open(LOG, File::RDWR|File::CREAT, 0644) do |log|
    log.flock(File::LOCK_EX)

    Dir.chdir '/srv/svn/Bills' do
      `svn cleanup`
      `svn update`
    end
  end

else
  puts mail.subject # temporary test
end

