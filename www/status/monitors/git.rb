#
# Monitor status of git updates
#
=begin
Sample input: See DATA section

Output status level can be:
Success - workspace is up to date
Info - one or more files updated
Warning - partial response
Danger - unexpected text in log file

=end

require 'fileutils'

SUMMARY_RE = %r{^ \d+ files? changed(, \d+ insertions?\(\+\))?(, \d+ deletions?\(-\))?$}

def Monitor.git(previous_status)
  logdir = File.expand_path('../../../logs', __FILE__)
  log = File.join(logdir, 'git-pull')

  archive = File.join(logdir, 'archive')
  FileUtils.mkdir(archive) unless File.directory?(archive)

  # read cron log
  if __FILE__ == $0 # unit test
    fdata = DATA.read
  else
    fdata = File.open(log) {|file| file.flock(File::LOCK_EX); file.read}
  end

  updates = fdata.split(%r{\n(?:/\w+)*/srv/git/})[1..-1]

  status = {}
  seen_level = {}

  # extract status for each repository
  updates.each do |update|
    level = 'success'
    title = nil
    data = revision = update[/^(Already up-to-date.|Updating [0-9a-f]+\.\.[0-9a-f]+)$/]
    title = update[SUMMARY_RE]
    show 'data', data

    lines = update.split("\n")
    repository = lines.shift.to_sym
    show 'repository', repository

    start_ignores = [
      'Already ',
      'Your branch is up-to-date with',
      'Your branch is behind',
      '  (use "git pull" ',
      'Fast-forward',
      'Updating ',
      ' create mode ',
      ' rename ',
      # TODO Should these 3 lines be handled differently?
      'From git://',
      ' * [new branch]',
      'From https://',
    ]
      
    lines.reject! do |line| 
      line.start_with?(*start_ignores) or
      line =~ SUMMARY_RE or
      line =~  /^ +[0-9a-f]+\.\.[0-9a-f]+ +\S+ +-> \S+$/ or # branch
      line =~  /^ +\+ [0-9a-f]+\.\.\.[0-9a-f]+ +\S+ +-> \S+ +\(forced update\)$/ # branch
    end

    unless lines.empty?
      level = 'info'
      data = lines.dup
    end

    # Drop the individual file details
    lines.reject! {|line|
      # certbot-route53/certbot_route53/authenticator.py | 6 +-----
      line =~  /^ \S+ +\|  ?\d+/ or
      # {certbot-route53 => certbot-dns-route53}/.gitignore          |  0
      line =~  /^ \S+ => \S+ +\|  ?\d+/
    }

    show 'lines', lines
    if lines.empty?
      if not data
        title = "partial response"
        level = 'warning'
        seen_level[level] = true
      elsif String  === data
        title = "No files updated"
      end

      data << revision if revision and data.instance_of? Array
    else
      level = 'danger'
      data = lines.dup
      title = nil
      seen_level[level] = true
    end

    status[repository] = {level: level, data: data, href: '../logs/svn-update'}
    status[repository][:title] = title if title
  end

  # save as the highest level seen
  %w{danger warning}.each do |lvl|
    if seen_level[lvl]
      # Save a copy of the log; append the severity so can track more problems
      file = File.basename(log)
      if __FILE__ == $0 # unit test
        puts "Would copy log to " + File.join(archive, file + '.' + lvl)
      else
        FileUtils.copy log, File.join(archive, file + '.' + lvl), preserve: true
      end
      break
    end
  end
  
  {data: status}
end

private

def show(name,value)
#  $stderr.puts "#{name}='#{value.to_s}'"
end

# for debugging purposes
if __FILE__ == $0
  require_relative 'unit_test'
  runtest('git') # must agree with method name above
#  DATA.each do |l|
#    puts l
#  end
end

# test data
__END__

/x1/srv/git/infrastructure-puppet
Already on 'deployment'
Your branch is behind 'origin/deployment' by 1 commit, and can be fast-forwarded.
  (use "git pull" to update your local branch)
Updating 74bdd49..83e4220
Fast-forward
 data/ubuntu/1404.yaml                     |  1 +
 data/ubuntu/1604.yaml                     |  1 +
 modules/build_slaves/manifests/jenkins.pp | 38 +++++++++++++++++++-------------------
 3 files changed, 21 insertions(+), 19 deletions(-)

/x1/srv/git/infrastructure-puppet2
Already on 'deployment'
Your branch is up-to-date with 'origin/deployment'.
Already up-to-date.

/x1/srv/git/infrastructure-puppet3
Already on 'deployment'
Your branch is up-to-date with 'origin/deployment'.
From git://git.apache.org/infrastructure-puppet
 * [new branch]      humbedooh/multimail-1.5 -> origin/humbedooh/multimail-1.5
Already up-to-date.

/x1/srv/git/infrastructure-puppet4
Already on 'deployment'
Your branch is up-to-date with 'origin/deployment'.
From git://git.apache.org/infrastructure-puppet
   83e4220..7394a6e  deployment -> origin/deployment
Updating 83e4220..7394a6e
Fast-forward
 modules/gitbox/files/asfgit/git_multimail.py | 1009 +++++++++++++++++++-------
 1 file changed, 737 insertions(+), 272 deletions(-)

/x1/srv/git/infrastructure-puppet5
Already on 'deployment'
Your branch is up-to-date with 'origin/deployment'.
From git://git.apache.org/infrastructure-puppet
   f827a83..b649da5  deployment -> origin/deployment
Updating f827a83..b649da5
Fast-forward
 .../git_mirror_asf/files/bin/graduate-podling.py   | 159 +++++++++++++++++++++
 1 file changed, 159 insertions(+)
 create mode 100644 modules/git_mirror_asf/files/bin/graduate-podling.py

/x1/srv/git/letsencrypt
Already up-to-date.

/x1/srv/git/letsencrypt2
From https://github.com/letsencrypt/letsencrypt
   d25069d..6ee934b  master     -> origin/master
Updating d25069d..6ee934b
Fast-forward
 certbot-route53/certbot_route53/authenticator.py | 6 +-----
 1 file changed, 1 insertion(+), 5 deletions(-)

/x1/srv/git/letsencrypt3
From https://github.com/letsencrypt/letsencrypt
   0e4f559..2325438  master     -> origin/master
 + 9564bce...e40eba0 fix-oldest-tests -> origin/fix-oldest-tests  (forced update)
   8061f7a..41098b3  ipv6       -> origin/ipv6
Updating 0e4f559..2325438
Fast-forward
 certbot-route53/certbot_route53/authenticator.py      | 14 +++++++++-----
 certbot-route53/certbot_route53/authenticator_test.py | 18 +++++++-----------
 2 files changed, 16 insertions(+), 16 deletions(-)

/x1/srv/git/letsencrypt4
From https://github.com/letsencrypt/letsencrypt
   7531c98..e0f3c05  master     -> origin/master
   8a46a0c..a8e4143  fix-oldest-tests -> origin/fix-oldest-tests
   d283103..ca4538b  ipv6       -> origin/ipv6
Updating 7531c98..e0f3c05
Fast-forward
 {certbot-route53 => certbot-dns-route53}/.gitignore          |  0
 {certbot-route53 => certbot-dns-route53}/LICENSE             |  0
 {certbot-route53 => certbot-dns-route53}/MANIFEST.in         |  0
 {certbot-route53 => certbot-dns-route53}/README.md           |  2 +-
 .../certbot_dns_route53}/__init__.py                         |  0
 certbot-dns-route53/certbot_dns_route53/authenticator.py     | 12 ++++++++++++
 .../certbot_dns_route53/dns_route53.py                       |  4 ++--
 .../certbot_dns_route53/dns_route53_test.py                  |  6 +++---
 .../examples/sample-aws-policy.json                          |  2 +-
 {certbot-route53 => certbot-dns-route53}/setup.cfg           |  0
 {certbot-route53 => certbot-dns-route53}/setup.py            |  7 ++++---
 .../tools/tester.pkoch-macos_sierra.sh                       |  0
 certbot/cli.py                                               |  3 +++
 certbot/plugins/disco.py                                     |  1 +
 certbot/plugins/selection.py                                 |  5 ++++-
 tests/letstest/scripts/test_apache2.sh                       |  2 +-
 tools/venv.sh                                                |  2 +-
 tools/venv3.sh                                               |  2 +-
 tox.cover.sh                                                 |  6 +++---
 tox.ini                                                      |  8 ++++----
 20 files changed, 41 insertions(+), 21 deletions(-)
 rename {certbot-route53 => certbot-dns-route53}/.gitignore (100%)
 rename {certbot-route53 => certbot-dns-route53}/LICENSE (100%)
 rename {certbot-route53 => certbot-dns-route53}/MANIFEST.in (100%)
 rename {certbot-route53 => certbot-dns-route53}/README.md (97%)
 rename {certbot-route53/certbot_route53 => certbot-dns-route53/certbot_dns_route53}/__init__.py (100%)
 create mode 100644 certbot-dns-route53/certbot_dns_route53/authenticator.py
 rename certbot-route53/certbot_route53/authenticator.py => certbot-dns-route53/certbot_dns_route53/dns_route53.py (96%)
 rename certbot-route53/certbot_route53/authenticator_test.py => certbot-dns-route53/certbot_dns_route53/dns_route53_test.py (97%)
 rename {certbot-route53 => certbot-dns-route53}/examples/sample-aws-policy.json (91%)
 rename {certbot-route53 => certbot-dns-route53}/setup.cfg (100%)
 rename {certbot-route53 => certbot-dns-route53}/setup.py (88%)
 rename {certbot-route53 => certbot-dns-route53}/tools/tester.pkoch-macos_sierra.sh (100%)
