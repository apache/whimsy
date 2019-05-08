#!/usr/bin/env ruby
# Analyze mbox files for general statistics into CSV
# - Per list messages per month over time (PMOT)
# - Count messages group by list -> graph months as time
# - Per list contentlines per lists PMOT
# - Per user statistics
# Count lines of text content in mail body, roughly attempting to 
#   count just new content (not automated, not > replies)

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
require 'mail'
require 'csv'
require 'stringio'
require 'zlib'
require 'json'
require 'date'
MBOX_EXT = '.mbox'
MEMBER = 'member'
COMMITTER = 'committer'
COUNSEL = 'counsel'

# Subject regexes that are non-discussion oriented
# Analysis: don't bother with content lines in these messages, 
#   because most of the content is tool-generated
NONDISCUSSION_SUBJECTS = { # Note: none applicable to members@
  '<board.apache.org>' => {
    missing: /\AMissing\s\S+\sBoard/,
    feedback: /\ABoard\sfeedback\son\s20/,
    notice: /\A\[NOTICE\]/i,
    report: /\A\[REPORT\]/i,
    resolution: /\A\[RESOLUTION\]/i,
    svn_agenda: %r{\Aboard: r\d{4,8} - /foundation/board/},
    svn_iclas: %r{\Aboard: r\d{4,8} - /foundation/officers/iclas.txt}
  },
  '<operations.apache.org>' => {
    notice: /\A\[NOTICE\]/i,
    report: /\A\[REPORT\]/i,
    svn_general: %r{\Asvn commit: r/},
    svn_bills: %r{\Abills: r\d{4,8} -}
  },
  '<trademarks.apache.org>' => {
    report: /\A\[REPORT\]/i,
    svn_general: %r{\Asvn commit: r/}
  },
  '<fundraising.apache.org>' => {
    report: /\A\[REPORT\]/i,
    svn_bills: %r{\Abills: r\d{4,8} -}
  }
}

# Read a ponyapi.rb mbox file and return mails (text content only)
# @param f path to .mbox or .mbox.gz
# @return [mail1, mail2, ...]
def read_mbox(f)
  if f.end_with? '.gz'
    stream = StringIO.new(mbox)
    reader = Zlib::GzipReader.new(stream)
    mbox = reader.read
    reader.close
    stream.close rescue nil
  else
    mbox = File.read(f)
  end
  mbox.force_encoding Encoding::ASCII_8BIT
  messages = mbox.split(/^From .*/)
  messages.shift # Drop first item (not a message)
  return messages
end

# Process an mbox file into mailhash of selected headers and lines of text
# @param f path to .mbox or .mbox.gz
# @return [mail1hash, mail2hash, ...], [ [parseerr, order], ...]
# @return nil, [read, errors2...] if mbox file can't be read
# mailhash contains :from, :subject, :listid, :date, :messageid, 
#   :inreplyto, :lines (count), plus :who and :committer
def mbox2stats(f)
  begin
    mails = read_mbox(f)
  rescue => e
    return nil, e
  end
  errs = []
  messages = []
  order = 0
  mails.each do |message|
    mdata = {}
    mail = nil
    begin
      # Preserve message order in case it's important
      order += 1
      # Enforce linefeeds; makes Mail happy; borks binary attachments (not used in this script)
      mail = Mail.read_from_string(message.gsub(/\r?\n/, "\r\n"))
      mdata[:order] = order
      begin # HACK for cases where some values don't parse, try to get good enough values in rescue
        mdata[:from] = mail[:from].value
        mdata[:subject] = mail[:subject].value
        mdata[:listid] = mail[:List_Id].value
        mdata[:date] = mail.date.to_s
      rescue => ee
        mdata[:from] = mail[:from]
        mdata[:subject] = mail[:subject]
        mdata[:listid] = mail[:List_Id]
        mdata[:date] = mail.date.to_s
        mdata[:parseerr] = mail.errors
      end
      mdata[:messageid] = mail.message_id
      mdata[:inreplyto] = mail.in_reply_to
      if mail.multipart?
        text_part = mail.text_part.decoded.split(/\r?\n/)
      else
        text_part = mail.body.decoded.split(/\r?\n/)
      end
      ctr = 0 # Count text lines of nonblank, nonreply content
      text_part.each do |l|
        case l
        when /\A\s*>/
          # Don't count reply lines, even when indented
        when /\A\s*\z/
          # Don't count blank lines
        when /\AOn.*wrote:\z/
          # Don't count most common reply header
        when /\A-----Original Message-----/
          # Stop counting if it seems like a forwarded message
          break
        else
          ctr += 1
        end
      end
      mdata[:lines] = ctr
      # Annotate various other precomputable data
      find_who_from mdata
      begin
        d = DateTime.parse(mdata[:date])
        mdata[:y] = d.year
        mdata[:m] = d.month
        mdata[:d] = d.day
        mdata[:w] = d.wday
        mdata[:h] = d.hour
        mdata[:z] = d.zone
      rescue => noop
        # no-op - not critical
        puts "DEBUG: #{e.message} parsing: #{mdata[:date]}"
      end
      regex = NONDISCUSSION_SUBJECTS[mdata[:listid]] # Use subject regex for this list (if any)
      if regex
        regex.each do |typ, rx|
          if mdata[:subject] =~ rx
            mdata[:nondiscuss] = typ
            break # regex.each
          end
        end
      end
      # Push our hash 
      messages << mdata
    rescue => e
      errs << [e, mdata[:order]]
    end
  end
  return messages, errs
end

# Annotate mailhash by adding :who and :committer (where known)
# @param mdata Hash to evaluate and annotate
# Side effect: adds :who and :committer from ASF::Person.find_by_email
# :committer = 'n' if not found; 'N' if error, 'counsel' for special case
def find_who_from(mdata)
  # Micro-optimize unique names
  case mdata[:from]
  when /Mark.Radcliffe/i
    mdata[:who] = 'Mark.Radcliffe'
    mdata[:committer] = COUNSEL
  when /mattmann/i
    mdata[:who] = 'Chris Mattmann'
    mdata[:committer] = MEMBER
  when /jagielski/i
    mdata[:who] = 'Jim Jagielski'
    mdata[:committer] = MEMBER
  when /delacretaz/i
    mdata[:who] = 'Bertrand Delacretaz'
    mdata[:committer] = MEMBER
  when /curcuru/i
    mdata[:who] = 'Shane Curcuru'
    mdata[:committer] = MEMBER
  when /steitz/i
    mdata[:who] = 'Phil Steitz'
    mdata[:committer] = MEMBER
  when /gardler/i  # Effectively unique (see: Heidi)
    mdata[:who] = 'Ross Gardler'
    mdata[:committer] = MEMBER
  when /Craig (L )?Russell/i # Optimize since Secretary sends a lot of mail
    mdata[:who] = 'Craig L Russell'
    mdata[:committer] = MEMBER
  when /McGrail/i
    mdata[:who] = 'Kevin A. McGrail'
    mdata[:committer] = MEMBER
  when /sallykhudairi@yahoo/i 
    mdata[:who] = 'Sally Khudairi'
    mdata[:committer] = MEMBER
  when /sk@haloworldwide.com/i
    mdata[:who] = 'Sally Khudairi'
    mdata[:committer] = MEMBER
  else
    begin
      # TODO use Real Name (JIRA) to attempt to lookup some notifications
      tmp = liberal_email_parser(mdata[:from])
      person = ASF::Person.find_by_email(tmp.address.dup)
      if person
        mdata[:who] = person.cn
        if person.asf_member?
          mdata[:committer] = MEMBER
        else
          mdata[:committer] = COMMITTER
        end
      else
        mdata[:who] = "#{tmp.display_name} <#{tmp.address}>"
        mdata[:committer] = 'n'
      end
    rescue
      mdata[:who] = mdata[:from]
      mdata[:committer] = 'N'
    end
  end
end

# @see www/secretary/workbench/models/message.rb
# @see https://github.com/mikel/mail/issues/39
def liberal_email_parser(addr)
  begin
    addr = Mail::Address.new(addr)
  rescue
    if addr =~ /^"([^"]*)" <(.*)>$/
      addr = Mail::Address.new
      addr.address = $2
      addr.display_name = $1
    elsif addr =~ /^([^"]*) <(.*)>$/
      addr = Mail::Address.new
      addr.address = $2
      addr.display_name = $1
    else
      raise
    end
  end
  return addr
end

# Scan dir tree for mboxes and output individual mailhash as JSONs
# @param dir to scan (whole tree)
# @param ext file extension to glob for
# Side effect: writes out f.chomp(ext).json files
def scan_dir_mbox2stats(dir, ext = MBOX_EXT)
  Dir["#{dir}/**/*#{ext}".untaint].each do |f|
    mails, errs = mbox2stats(f.untaint)
    File.open("#{f.chomp(ext)}.json", "w") do |fout|
      fout.puts JSON.pretty_generate([mails, errs])
    end
  end
end

# Scan dir tree for mailhash JSONs and output an overview CSV of all
# @return [ error1, error2, ...] if any errors
# Side effect: writes out dir/outname CSV file
def scan_dir_stats2csv(dir, outname)
  errors = []
  filenames = Dir["#{dir}/**/*.json".untaint]
  raise ArgumentError, "#{__method__} called with no files in #{dir}" if filenames.length == 0
  puts "#{__method__} processing #{filenames.length} files"
  firstfile = filenames.shift
  jzon = JSON.parse(File.read(firstfile))
  # Write out headers and the first file in new csv
  csvfile = File.join("#{dir}", outname)
  csv = CSV.open(csvfile, "w", headers: %w( year month day weekday hour zone listid who subject lines committer messageid inreplyto ), write_headers: true)
  jzon[0].each do |m|
    csv << [ m['y'], m['m'], m['d'], m['w'], m['h'], m['z'], m['listid'], m['who'], m['subject'], m['lines'], m['committer'], m['messageid'], m['inreplyto']  ]
  end
  
  # Write out all remaining files, without headers, appending
  filenames.each do |f|
    begin
      j = JSON.parse(File.read(f))
      j[0].each do |m|
        csv << [ m['y'], m['m'], m['d'], m['w'], m['h'], m['z'], m['listid'], m['who'], m['subject'], m['lines'], m['committer'], m['messageid'], m['inreplyto']  ]
      end
    rescue => e
      puts "ERROR: parse/write of #{f} raised #{e.message[0..255]}"
      errors << "#{e.message}\n\t#{e.backtrace.join("\n\t")}"
      next
    end
  end
  csv.close # Just in case
  return errors
end

# Aggregate selected header fields from an mbox
# @deprecated TODO use mbox2stats et al instead
def scan_mbox_headers(f, headers)
  begin
    messages = read_mbox(f)
  rescue => e
    puts "ERROR:scan_mbox_hdr(#{f}) #{e}"
    return
  end
  begin
    messages.each do |message|
      header = {}
      catch :headerend do
        lines = message.split(/\n/)
        lines.shift # Drop first bogus line
        lines.each do |line|
          throw :headerend if line == ""
          case line
          when /^Subject: (.*)/
            header[:subject] = "#{$1}"
          when /^From: (.*)/
            header[:from] = "#{$1}"
          when /^Date: (.*)/
            header[:date] = "#{$1}"
          when /^List-Id: <(.*)>/
            header[:listid] = "#{$1}"
          when /^Message-ID: <(.*)>/
            header[:messageid] = "#{$1}"
          when /^In-Reply-To: <(.*)>/
            header[:inreplyto] = "#{$1}"
          end
        end
      end
      headers << header
    end
    return
  rescue => e
    puts e # TODO rationalize error processing
    return ["ERROR:scan_mbox_hdr(#{f}) #{e.message[0..255]}", "\t#{e.backtrace.join("\n\t")}"]
  end
end

# Return headers for a directory of mboxes
# @deprecated TODO use mbox2stats et al instead
def scan_dir_headers(dir, ext)
  headers = []
  errs = []
  Dir["#{dir}/**/*#{ext}*".untaint].each do |f|
    headers, errs = scan_mbox_headers(f.untaint, headers)
  end
  annotate_headers(headers)
  return headers
end

# Simple header annotations for best guesses of ASF attributes related to trademarks@
# @deprecated TODO use mbox2stats et al instead
# TODO Only additional feature is setting header[:type], which is list-specific
SHANE = 'Shane'
def annotate_headers(headers)
  headers.each do |header|
    if header[:from] =~ /\(JIRA\)/
      header[:type] = 'JIRA'
    elsif header[:subject] =~ /\Asvn commit/
      header[:type] = 'SVN'
    elsif header[:subject] =~ /\A\[REPORT\] /
      header[:type] = 'REPORT'
    elsif header[:subject] =~ /\A\[[A-Z]{5,6}\] / # mailto: from website
      header[:type] = 'Question-Web'
    else
      header.key?(:inreplyto) ? header[:type] = '' : header[:type] = 'Question' # Presumably a new incoming question
    end
    
    if header[:from] =~ /\AShane Curcuru \(JIRA/i # Optimize case for trademarks@
      header[:who] = 'Shane-JIRA'
      header[:committer] = SHANE
    elsif header[:from] =~ /Shane Curcuru/i # Optimize case for trademarks@
      header[:who] = 'Shane'
      header[:committer] = SHANE
    elsif header[:from] =~ /\AVice President, Brand Management/i # Optimize case for trademarks@
      header[:who] = 'Shane-VP'
      header[:committer] = SHANE
    elsif header[:from] =~ /jira@/i # Optimize case for trademarks@, hackish
      header[:who] = header[:from].sub("<jira@apache.org>", '').gsub('""', '')
      header[:committer] = COMMITTER
    else
      begin
        tmp = liberal_email_parser(header[:from])
        person = ASF::Person.find_by_email(tmp.address.dup)
        if person
          header[:who] = person.cn
          if person.asf_member?
            header[:committer] = MEMBER
          else
            header[:committer] = COMMITTER
          end
        else
          header[:who] = tmp.display_name
          header[:committer] = 'n'
        end
      rescue
        header[:who] = header[:from]
        header[:committer] = 'N'
      end
    end
  end
end

# Common use case - analyze headers in mbox files to see who asks questions on trademarks@
# @deprecated TODO use mbox2stats et al instead
def do_mbox2csv_hdr(dir)
  headers = scan_dir_headers(dir, MBOX_EXT)
  CSV.open(File.join("#{dir}", "mboxhdr2csv.csv"), "w", headers: %w( date who subject messageid committer question ), write_headers: true) do |csv|
    headers.each do |h|
      csv << [h[:date], h[:who], h[:subject], h[:messageid], h[:committer], h[:type] ]
    end
  end
end

#### TODO Sample code
path = '~/src/lists'
output = 'listdata.csv'
puts "START: #{path} into #{output}"
scan_dir_mbox2stats(path)
errs = scan_dir_stats2csv(path, output)
if errs
  errs.each do |e|
    puts "ERROR: #{e}"
  end
end
puts "END"