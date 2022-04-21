#
# When mail comes in indicating that a repository was updated,
# update the local working copy.
#
#  N.B. the directory paths need to agree with repository.yml

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/lockfile'

require 'mail'

File.umask(0o002)

STDIN.binmode
mail = Mail.new(STDIN.read)

# N.B. Output goes to the procmail file at /srv/svn/procmail.log
def update(dir)
  LockFile.lockfile(dir, nil, File::LOCK_EX) do # ignore the block parameter
    $stderr.puts "#{Time.now} Updating #{dir}" # Record updates
    Dir.chdir dir do
      $stderr.puts `svn cleanup`
      $stderr.puts `svn update`
    end
  end
end

# N.B. Please ensure any required list subscriptions are noted in DEPLOYMENT.md
subject = mail.subject # fetch once

if subject =~ %r{^board: r\d+ -( in)? /foundation/board} # board-commits@

  update '/srv/svn/foundation_board'

# N.B. subject may contain other files
elsif subject =~ %r{^foundation: r\d+ -} # generic foundation commit prefix

  if subject =~ %r{ /foundation/members.txt}
    # Now only has members.txt
    update '/srv/svn/foundation'
  end

  # Changes to requests-received are important for the workbench to know
  # when a request has been processed, so it's worth processing asap
  if subject =~ %r{ /documents/emeritus-requests-received/}
    require 'whimsy/asf/config'
    require 'whimsy/asf/svn'
    svnrepos = ASF::SVN.repo_entries(true) || {}
    name = 'emeritus-requests-received'
    description = svnrepos[name]
    if description
      $stderr.puts "Updating listing for #{name}"
      # This ought to be done by pubsub2rake; check that is the case by disabling the update here
      $stderr.puts (File.open('/srv/svn/emeritus-requests-received.txt').readline.chomp rescue '??')
      # old, new = ASF::SVN.updatelisting(name, nil, nil, description['dates'])
      # if old == new
      #   $stderr.puts "List is at revision #{old}."
      # elsif old.nil?
      #   $stderr.puts "Created list at revision #{new}"
      # else
      #   $stderr.puts "List updated from #{old} to revision #{new}."
      # end
    else
      $stderr.puts "Could not find #{name} in repository.yml"
    end
  end

elsif subject =~ %r{^committers: r\d+ -( in)? /committers/board} # committers-cvs@

  update '/srv/svn/board'

end
