#!/usr/bin/env ruby

# @(#) merge subs information from old and new mail list servers during changeover

#        ***********  DRAFT  *****************
#        ***********  DRAFT  *****************

# The mail list server is being migrated to a new host.
# This means some mail lists are on a new host whilst some are on the old host.
# It looks as though the old list files are not being removed, so merging must
# use entries from the new host, filling in from the old host where necessary.

# To allow the mail parsing utils to continue to work as far as possible during
# the changeover, we merge the old and new data files.

# Assume we have new data under /NEW/;
# old data under /OLD/; and
# output is under /OUT/.

# For each entry under /NEW/cache, create a link under /OUT/cache/, replacing any existing entry.
# For each file under /OLD/cache, create a link under /OUT/cache/ -- if none exists

# The following top-level files also need to be merged:
# qmail.ids = read both files, and eliminate duplicates
# list-flags = read old file, storing in hash (dom+list); merge in new; write out merged
# list-start - copy from NEW directory at end of run
# list-counts - merge (apart from total)

require 'find'
require 'fileutils'

def merge_files(old_host, new_host, out)
  # merge list-counts
  counts = {}
  File.open(File.join(old_host, 'list-counts')).each do |line|
    if line =~ %r{^( *\d+) (\S+)}
      counts[$2] = $1
    else
      puts "Unexpected count line #{line}"
    end
  end

  File.open(File.join(new_host, 'list-counts')).each do |line|
    if line =~ %r{^( *\d+) (\S+)}
      counts[$2] = $1
    else
      puts "Unexpected count line #{line}"
    end
  end

  File.open(File.join(out, 'list-counts'), 'w') do |f|
    counts.delete('total') # does not sort correctly; and cannot be merged
    counts.sort.each do |k, v|
      f.puts "#{v} #{k}"
    end
  end

  # merge list-flags
  old_flags = File.join(old_host, 'list-flags')
  new_flags = File.join(new_host, 'list-flags')
  out_flags = File.join(out, 'list-flags')
  out_time = File.mtime(out_flags) rescue 0
  # only update flags if they have changed
  if File.mtime(old_flags) > out_time || File.mtime(new_flags) > out_time

    flags = {}
    File.open(old_flags).each do |line|
      parts = line.chomp.split(' ', 2)
      flags[parts[1]] = parts[0]
    end

    File.open(new_flags).each do |line|
      parts = line.chomp.split(' ', 2)
      flags[parts[1]] = parts[0]
    end

    File.open(out_flags, 'w') do |f|
      flags.sort.each do |k, v|
        f.puts "#{v} #{k}"
      end
    end

  end

    # Create links to new cache files as necessary
  Find.find(File.join(new_host, 'cache')) do |path|
    if File.file? path
      targ = path.sub(new_host, out)
      dir = File.dirname(targ)
      unless File.directory? dir
        # puts "Making #{dir}"
        FileUtils.mkdir_p dir
      end
      # puts "Linking #{targ}"
      # Always create a link
      FileUtils.symlink path, targ, force: true
    end
  end

  # Now fill in any gaps from the old host
  Find.find(File.join(old_host, 'cache')) do |path|
    if File.file? path
      targ = path.sub(old_host, out)
      # At the start of a merge, there may be plain files from before
      # These need to be replaced with soft links
      unless File.exist?(targ) && File.ftype(targ) == 'link'
        dir = File.dirname(targ)
        unless File.directory? dir
          # puts "Making #{dir}"
          FileUtils.mkdir_p dir
        end
        # puts "Linking #{targ}"
        FileUtils.symlink path, targ, force: true
      end
    end
  end

  # Remove any dangling files/links (e.g. after a list is removed)
  Find.find(File.join(out, 'cache')) do |path|
    next if File.directory? path
    unless File.exist?(path) && File.ftype(path) == 'link'
      $stderr.puts "WARN: Removing real file or missing link #{path}"
      begin
        File.unlink(path)
      rescue StandardError => e
        $stderr.puts "WARN: Failed to remove path #{e.inspect}"
      end
    end
  end

  # Update the timestamp
  FileUtils.copy_file(File.join(new_host, 'list-start'), File.join(out, 'list-start'), true)
end

# merge qmail.ids
def merge_qmail(old_host, new_host, out)
  merged = File.read(File.join(old_host, 'qmail.ids')).
    split("\n").union(File.read(File.join(new_host, 'qmail.ids')).split("\n"))
  File.write(File.join(out, 'qmail.ids'), merged.join("\n"))
end

OLD = '/srv/subscriptions1' # old host puts files here
NEW = '/srv/subscriptions2' # new host puts files here
OUT = '/srv/subscriptions' # Whimsy expects the files here

if __FILE__ == $0
#   type = ARGV.shift
#   if type == 'qmail'
#     merge_qmail OLD, NEW, OUT
#   elsif type == 'files'
#     merge_files OLD, NEW, OUT
#   else
#     raise "Unexpected merge type: expected 'qmail' or 'files'"
#   end
end


# TODO: link this into a file update checker
