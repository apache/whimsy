#
# When mail comes in indicating that a repository was updated,
# update the local working copy.
#

require 'mail'

File.umask(0o002)

STDIN.binmode
mail = Mail.new(STDIN.read)

# N.B. Output goes to the procmail file at /srv/svn/procmail.log
def update(dir)
  $stderr.puts "#{Time.now} Updating #{dir}" # Record updates
  Dir.chdir dir do
    $stderr.puts `svn cleanup`
    $stderr.puts `svn update`
  end
end

# N.B. Please ensure any required list subscriptions are noted in DEPLOYMENT.md
subject = mail.subject # fetch once

if subject =~ %r{^board: r\d+ -( in)? /foundation/board} # board-commits@

  update '/srv/svn/foundation_board'

# N.B. subject may contain other files
elsif subject =~ %r{^foundation: r\d+ -.* /foundation/members.txt} # foundation-commits@

  # Now only has members.txt
  update '/srv/svn/foundation'

elsif subject =~ %r{^committers: r\d+ -( in)? /committers/board} # committers-cvs@

  update '/srv/svn/board'

end

