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
    fdata = File.open(log, 'r:UTF-8') do |file|
      file.flock(File::LOCK_EX)
      file.read
    end
  end

  updates = fdata.split(%r{\n(?:/\w+)*/srv/git/})[1..-1]

  status = {}
  seen_level = {}

  # extract status for each repository
  updates.each do |update|
    show 'update', update
    level = 'success'
    title = nil
    data = revision = update[/^(Already up-to-date.|Updating [0-9a-f]+\.\.[0-9a-f]+|HEAD is now at [0-9a-f]+.+)$/]
    title = update[SUMMARY_RE]
    show 'data', data

    lines = update.split("\n")
    repository = lines.shift.to_sym
    show 'repository', repository

    start_ignores = [
      'Already ',
      'Your branch is up-to-date with',
      'Your branch is up to date with',
      'Your branch is behind',
      '  (use "git pull" ',
      'Fast-forward',
      'Updating ',
      ' create mode ',
      ' delete mode ',
      ' rename ',
      ' mode change ',
      'HEAD is now at ',
      # TODO Should these 3 lines be handled differently?
      'From git://',
      ' * [new branch]',
      ' * [new tag]',
      'From https://',
      'Auto packing the repository',
      'See "git help gc" for manual housekeeping',
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
      line =~  /^ \S+ +\| +\d+/ or
      # {certbot-route53 => certbot-dns-route53}/.gitignore          |  0
      line =~  /^ \S+ => \S+ +\| +\d+/ or
      #  certbot/tests/testdata/{csr.der => csr_512.der}    | Bin
      line =~  /^ \S+ => \S+ +\| Bin/ or
      # letsencrypt-auto-source/letsencrypt-auto.sig       | Bin 256 -> 256 bytes
      line =~  /^ \S+ +\| Bin \d+ -> \d+ bytes/
    }

    show 'lines', lines
    if lines.empty?
      if not data
        title = "partial response"
        level = 'warning'
        seen_level[level] = true
      elsif data.is_a? String
        title = "No files updated"
      end

      data << revision if revision and data.instance_of? Array
    else
      level = 'danger'
      data = lines.dup
      title = nil
      seen_level[level] = true
    end

    status[repository] = {level: level, data: data, href: '../logs/git-pull'}
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
  response = Monitor.git(nil) # must agree with method name above
  data = response[:data]
  data.each do |k,v|
    puts "#{k} #{data[k][:level]} #{data[k][:title] or data[k][:data] }"
  end
end

# test data
__END__

/x1/srv/git/infrapup
Already on 'deployment'
Your branch is behind 'origin/deployment' by 1 commit, and can be fast-forwarded.
  (use "git pull" to update your local branch)
Updating 74bdd49..83e4220
Fast-forward
 data/ubuntu/1404.yaml                     |  1 +
 data/ubuntu/1604.yaml                     |  1 +
 modules/build_slaves/manifests/jenkins.pp | 38 +++++++++++++++++++-------------------
 3 files changed, 21 insertions(+), 19 deletions(-)

/x1/srv/git/infrapup2
Already on 'deployment'
Your branch is up-to-date with 'origin/deployment'.
Already up-to-date.

/x1/srv/git/infrapup3
Already on 'deployment'
Your branch is up-to-date with 'origin/deployment'.
From git://git.apache.org/infrapup
 * [new branch]      humbedooh/multimail-1.5 -> origin/humbedooh/multimail-1.5
Already up-to-date.

/x1/srv/git/infrapup4
Already on 'deployment'
Your branch is up-to-date with 'origin/deployment'.
From git://git.apache.org/infrapup
   83e4220..7394a6e  deployment -> origin/deployment
Updating 83e4220..7394a6e
Fast-forward
 modules/gitbox/files/asfgit/git_multimail.py | 1009 +++++++++++++++++++-------
 1 file changed, 737 insertions(+), 272 deletions(-)

/x1/srv/git/infrapup5
Already on 'deployment'
Your branch is up-to-date with 'origin/deployment'.
From git://git.apache.org/infrapup
   f827a83..b649da5  deployment -> origin/deployment
Updating f827a83..b649da5
Fast-forward
 .../git_mirror_asf/files/bin/graduate-podling.py   | 159 +++++++++++++++++++++
 1 file changed, 159 insertions(+)
 create mode 100644 modules/git_mirror_asf/files/bin/graduate-podling.py

/x1/srv/git/infrapup6
Already on 'deployment'
Your branch is up-to-date with 'origin/deployment'.
From https://github.com/apache/infrapup
   1eaab02..bafa433  deployment -> origin/deployment
Updating 1eaab02..bafa433
Fast-forward
 .../files/projects/archive-snapshots-monthly.sh    | 14 -----
 .../files/projects/create-ofbiz-archives-index.sh  | 54 ------------------
 .../files/projects/create-ofbiz-snapshots-index.sh | 64 ----------------------
 .../files/projects/remove-snapshots-daily.sh       | 14 -----
 modules/buildbot_asf/manifests/init.pp             | 51 -----------------
 5 files changed, 197 deletions(-)
 delete mode 100755 modules/buildbot_asf/files/projects/archive-snapshots-monthly.sh
 delete mode 100755 modules/buildbot_asf/files/projects/create-ofbiz-archives-index.sh
 delete mode 100755 modules/buildbot_asf/files/projects/create-ofbiz-snapshots-index.sh
 delete mode 100755 modules/buildbot_asf/files/projects/remove-snapshots-daily.sh

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

/x1/srv/git/letsencrypt5
From https://github.com/letsencrypt/letsencrypt
 * [new branch]      0.15.x     -> origin/0.15.x
 * [new branch]      candidate-0.15.0 -> origin/candidate-0.15.0
 * [new tag]         v0.15.0    -> v0.15.0
Already up-to-date.

/x1/srv/git/letsencrypt6
From https://github.com/letsencrypt/letsencrypt
   a06dec3..895a525  master     -> origin/master
Updating a06dec3..895a525
Fast-forward
 acme/setup.py                                      |   2 +-
 certbot-apache/setup.py                            |   2 +-
 certbot-auto                                       | 124 ++++++------
 certbot-compatibility-test/setup.py                |   2 +-
 certbot-dns-cloudflare/setup.py                    |   2 +-
 certbot-dns-cloudxns/setup.py                      |   2 +-
 certbot-dns-digitalocean/setup.py                  |   2 +-
 certbot-dns-dnsimple/setup.py                      |   2 +-
 certbot-dns-google/setup.py                        |   2 +-
 certbot-dns-nsone/setup.py                         |   2 +-
 certbot-dns-route53/setup.py                       |   2 +-
 certbot-nginx/setup.py                             |   2 +-
 certbot/__init__.py                                |   2 +-
 docs/cli-help.txt                                  | 215 ++++++++++++++++-----
 letsencrypt-auto                                   | 124 ++++++------
 letsencrypt-auto-source/certbot-auto.asc           |  14 +-
 letsencrypt-auto-source/letsencrypt-auto           |  26 +--
 letsencrypt-auto-source/letsencrypt-auto.sig       | Bin 256 -> 256 bytes
 .../pieces/certbot-requirements.txt                |  24 +--
 19 files changed, 336 insertions(+), 215 deletions(-)

/x1/srv/git/letsencrypt7
From https://github.com/letsencrypt/letsencrypt
   c33ee0e..8ca36a0  master     -> origin/master
Updating c33ee0e..8ca36a0
Fast-forward
 certbot/plugins/common_test.py                     |   4 +-
 certbot/tests/account_test.py                      |   8 ++--
 certbot/tests/cert_manager_test.py                 |   2 +-
 certbot/tests/client_test.py                       |  14 +++---
 certbot/tests/crypto_util_test.py                  |  49 ++++++++++-----------
 certbot/tests/main_test.py                         |  18 ++++----
 certbot/tests/storage_test.py                      |  15 ++++---
 certbot/tests/testdata/README                      |  11 +++++
 .../{cert-5sans.pem => cert-5sans_512.pem}         |   0
 .../testdata/{cert-san.pem => cert-san_512.pem}    |   0
 certbot/tests/testdata/cert.b64jose                |   1 -
 certbot/tests/testdata/cert.der                    | Bin 377 -> 0 bytes
 .../{self_signed_cert.pem => cert_2048.pem}        |   0
 certbot/tests/testdata/{cert.pem => cert_512.pem}  |   0
 .../{self_signed_cert_bad.pem => cert_512_bad.pem} |   0
 ...igned_fullchain.pem => cert_fullchain_2048.pem} |   0
 certbot/tests/testdata/csr-6sans.pem               |  12 -----
 certbot/tests/testdata/csr-6sans_512.conf          |  29 ++++++++++++
 certbot/tests/testdata/csr-6sans_512.pem           |  12 +++++
 .../{csr-nonames.pem => csr-nonames_512.pem}       |   0
 certbot/tests/testdata/csr-nosans.pem              |   8 ----
 certbot/tests/testdata/csr-nosans_512.conf         |  16 +++++++
 certbot/tests/testdata/csr-nosans_512.pem          |   9 ++++
 .../testdata/{csr-san.pem => csr-san_512.pem}      |   0
 certbot/tests/testdata/{csr.der => csr_512.der}    | Bin
 certbot/tests/testdata/{csr.pem => csr_512.pem}    |   0
 certbot/tests/testdata/dsa512_key.pem              |  14 ------
 certbot/tests/testdata/dsa_cert.pem                |  17 -------
 certbot/tests/testdata/matching_cert.pem           |  14 ------
 certbot/tests/testdata/rsa512_key_2.pem            |   9 ----
 30 files changed, 134 insertions(+), 128 deletions(-)
 create mode 100644 certbot/tests/testdata/README
 rename certbot/tests/testdata/{cert-5sans.pem => cert-5sans_512.pem} (100%)
 rename certbot/tests/testdata/{cert-san.pem => cert-san_512.pem} (100%)
 delete mode 100644 certbot/tests/testdata/cert.b64jose
 delete mode 100644 certbot/tests/testdata/cert.der
 rename certbot/tests/testdata/{self_signed_cert.pem => cert_2048.pem} (100%)
 rename certbot/tests/testdata/{cert.pem => cert_512.pem} (100%)
 rename certbot/tests/testdata/{self_signed_cert_bad.pem => cert_512_bad.pem} (100%)
 rename certbot/tests/testdata/{self_signed_fullchain.pem => cert_fullchain_2048.pem} (100%)
 delete mode 100644 certbot/tests/testdata/csr-6sans.pem
 create mode 100644 certbot/tests/testdata/csr-6sans_512.conf
 create mode 100644 certbot/tests/testdata/csr-6sans_512.pem
 rename certbot/tests/testdata/{csr-nonames.pem => csr-nonames_512.pem} (100%)
 delete mode 100644 certbot/tests/testdata/csr-nosans.pem
 create mode 100644 certbot/tests/testdata/csr-nosans_512.conf
 create mode 100644 certbot/tests/testdata/csr-nosans_512.pem
 rename certbot/tests/testdata/{csr-san.pem => csr-san_512.pem} (100%)
 rename certbot/tests/testdata/{csr.der => csr_512.der} (100%)
 rename certbot/tests/testdata/{csr.pem => csr_512.pem} (100%)
 delete mode 100644 certbot/tests/testdata/dsa512_key.pem
 delete mode 100644 certbot/tests/testdata/dsa_cert.pem
 delete mode 100644 certbot/tests/testdata/matching_cert.pem
 delete mode 100644 certbot/tests/testdata/rsa512_key_2.pem

/x1/srv/git/infrapup7
Already on 'deployment'
Your branch is up-to-date with 'origin/deployment'.
From https://github.com/apache/infrapup
   b03cfe6..21a99b2  deployment -> origin/deployment
Updating b03cfe6..21a99b2
Fast-forward
 .../files/authorization/check-auth-templates.pl    |  16 +-
 .../files/authorization/gen_asf-authorization.pl   | 291 ---------------------
 .../files/authorization/pit-authorization-template |   2 +
 3 files changed, 10 insertions(+), 299 deletions(-)
 mode change 100644 => 100755 modules/subversion_server/files/authorization/check-auth-templates.pl
 delete mode 100755 modules/subversion_server/files/authorization/gen_asf-authorization.pl

/x1/srv/git/infrapup8
Already on 'deployment'
Your branch is up-to-date with 'origin/deployment'.
HEAD is now at 4aafd69 Merge pull request #720 from rubys/rubys/noauth-source

/x1/srv/git/letsencrypt8
From https://github.com/letsencrypt/letsencrypt
   e86bb7f..97ad9f9  plugin_storage -> origin/plugin_storage
HEAD is now at a2239ba fix test_tests.sh (#5478)

/x1/srv/git/infrapup9
Already on 'deployment'
Your branch is up-to-date with 'origin/deployment'.
From https://github.com/apache/infrapup
   228c0fb..8bbfaca  deployment -> origin/deployment
Auto packing the repository in background for optimum performance.
See "git help gc" for manual housekeeping.
HEAD is now at 8bbfaca Merge pull request #853 from sebbASF/zcat
