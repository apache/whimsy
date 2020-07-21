#!/usr/bin/env ruby

# Create local repo for testing
#
# - create a different repo for each top-level path (asf/infr/private)
# - for each relative URL, create the directory if necessary
# - for each file, copy from the ASF REPO if necessary

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'

ASF_REPO='https://svn.apache.org/repos/' # where to fetch files

LOCAL_FILE='/var/tools/svnrep' # Change this as required

LOCAL_URL='file://' + LOCAL_FILE

svnrepos = ASF::SVN.repo_entries(true)

# Find the top-level directories and create repositories
svnrepos.map{|k,v| v['url'].split('/')[0]}.uniq.sort.each do |tlr|
  repodir = File.join(LOCAL_FILE, tlr)
  unless File.exist? File.join(repodir, 'format')
    cmd = ['svnadmin','create',repodir]
    puts cmd.join(' ')
    system *cmd
  end
end

svnrepos.each do |name, entry|

  url = entry['url']
  svndir = File.join(LOCAL_URL, url)

  # if the relative URL does not exist, create the directory
  revision, err = ASF::SVN.getRevision(svndir)
  unless revision
    puts "Creating #{svndir}"
    system *%w(svn mkdir --parents --message Initial --), svndir
  end

  # for each file, if it does not exist, copy the file from the ASF repo
  # TODO it might be better to copy from samples
  (entry['files'] || []).each do |file|
    filepath = File.join(svndir,file)
    revision, err = ASF::SVN.getRevision(filepath)
    unless revision
      puts "Creating #{filepath}"
      Dir.mktmpdir do |tmp|
        infile = File.join(ASF_REPO, url, file)
        out = File.join(tmp, file)
        p infile
        system 'svn', 'export', infile, out
        cmd = %w(svnmucc --message "Initial_create" -- put)
        cmd << out
        cmd << filepath
        system *cmd
      end
    end
  end
  # Also need basic versions of:
  # grants.txt
  # cclas.txt
  # Meetings/yyyymmdd/memapp-received.txt where yyyymmdd is within the time limit (32 days?)
  #  acreq/new-account-reqs.txt
  # foundation_board/board_agenda_2020_08_19.txt (e.g.)
end
