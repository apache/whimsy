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

def update(dir)
  # prevent concurrent updates being performed by the cron job
  File.open(LOG, File::RDWR|File::CREAT, 0644) do |log|
    log.flock(File::LOCK_EX)

    $stderr.puts "#{Time.now} Updating #{dir}" # Record updates
    Dir.chdir dir do
      $stderr.puts `svn cleanup`
      $stderr.puts `svn update`
    end
  end
end

# N.B. Please ensure any required list subscriptions are noted in DEPLOYMENT.md

if mail.subject =~ %r{^board: r\d+ -( in)? /foundation/board} # board-commits@

  update '/srv/svn/foundation_board'

elsif mail.subject =~ %r{^foundation: r\d+ -( in)? /foundation} # foundation-commits@

  # includes members.txt
  update '/srv/svn/foundation'

elsif mail.subject =~ %r{^committers: r\d+ -( in)? /committers/board} # committers-cvs@

  update '/srv/svn/board'

end

