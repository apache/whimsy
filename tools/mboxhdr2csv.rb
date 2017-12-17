#!/usr/bin/env ruby
# Analyze mbox files either by headers or by content lines
$LOAD_PATH.unshift File.realpath(File.expand_path('../../lib', __FILE__))
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

# Analyzing mbox files for interesting statistics to report:
# Contentlines are only counted when ! has_key? nondiscuss
#   Rationale: svn, JIRA, automated messages are primarly tool-created
# Per list messages per month over time (PMOT)
# Count messages group by list -> graph months as time
# Per list contentlines per lists PMOT
# User messages per lists PMOT
# User contentlines per lists PMOT
# User msgs/lines by day of week; hour of day

# Read f.mbox or f.mbox.gz and return [message, message2, ...] or raise error
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

# Split mbox into [MailHash, Mail2Hash,...], [ [parseerr, order], ...]
# Returns nil, [read, errors2...] if mbox file can't be read
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
      find_who_from mdata
      messages << mdata
    rescue => e
      errs << [e, mdata[:order]]
    end
  end
  return messages, errs
end

# Scan dir of mbox and output json of statistics for each; return meta-array of all mdata
def scan_dir_mbox2stats(dir, ext)
  Dir["#{dir}/**/*#{ext}".untaint].each do |f|
    mails, errs = mbox2stats(f.untaint)
    puts "scan_mbox(#{f}) mails: #{mails.length} errors: #{errs.length}"
    File.open("#{f.chomp(ext)}.json", "w") do |fout|
      fout.puts JSON.pretty_generate([mails, errs])
    end
  end
end

# Add :who field and Apache committer status
def find_who_from(msg)
  # Micro-optimize unique names
  case msg[:from]
  when /mattmann/i
    msg[:who] = 'Chris Mattmann'
    msg[:committer] = MEMBER
  when /jagielski/i
    msg[:who] = 'Jim Jagielski'
    msg[:committer] = MEMBER
  when /delacretaz/i
    msg[:who] = 'Bertrand Delacretaz'
    msg[:committer] = MEMBER
  when /curcuru/i
    msg[:who] = 'Shane Curcuru'
    msg[:committer] = MEMBER
  when /steitz/i
    msg[:who] = 'Phil Steitz'
    msg[:committer] = MEMBER
  when /gardler/i  # Effectively unique (see: Heidi)
    msg[:who] = 'Ross Gardler'
    msg[:committer] = MEMBER
  when /Craig (L )?Russell/i # Optimize since Secretary sends a lot of mail
    msg[:who] = 'Craig L Russell'
    msg[:committer] = MEMBER
  when /McGrail/i
    msg[:who] = 'Kevin A. McGrail'
    msg[:committer] = MEMBER
  when /sallykhudairi@yahoo/i 
    msg[:who] = 'Sally Khudairi'
    msg[:committer] = MEMBER
  when /sk@haloworldwide.com/i
    msg[:who] = 'Sally Khudairi'
    msg[:committer] = MEMBER
  else
    begin
      # TODO use Real Name (JIRA) to attempt to lookup some notifications
      tmp = liberal_email_parser(msg[:from])
      person = ASF::Person.find_by_email(tmp.address.dup)
      if person
        msg[:who] = person.cn
        if person.asf_member?
          msg[:committer] = MEMBER
        else
          msg[:committer] = COMMITTER
        end
      else
        msg[:who] = "#{tmp.display_name} <#{tmp.address}>"
        msg[:committer] = 'n'
      end
    rescue
      msg[:who] = msg[:from]
      msg[:committer] = 'N'
    end
  end
end

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

# Annotate mbox stats hash w/nondiscussion marker (hint: don't count content lines)
def mark_nondiscussion(mails)
  ctr = 0
  mails.each do |msg|
    regex = NONDISCUSSION_SUBJECTS[msg['listid']] # Use subject regex for this list (if any)
    if regex
      regex.each do |typ, rx|
        if msg['subject'] =~ rx
          msg[:nondiscuss] = typ
          ctr += 1
          break
        end
      end
    end
  end
end

# Annotate mbox stats hash with various precomputed data
def annotate_stats(mails)
  mails.each do |msg|
    # Translate date into y, m, d, w (day of week), h, z (timezone), (no minutes)
    begin
      d = DateTime.parse(msg['date'])
      msg[:y] = d.year
      msg[:m] = d.month
      msg[:d] = d.day
      msg[:w] = d.wday
      msg[:h] = d.hour
      msg[:z] = d.zone
    rescue => e
      # no-op
      puts "DEBUG: #{e.message} parsing: #{msg['date']}"
    end
  end
end

# Scan dir of mbox .json stats and annotate with nondiscussion markers
# TODO: this should really be done on first parse pass, not later on
# @return array of any errors
def scan_dir_json_nondiscussion(dir)
  errors = []
  Dir["#{dir}/**/*.json".untaint].each do |f|
    begin
      jzon = JSON.parse(File.read(f))
      msgs = jzon[0]  # Should be an array of [[msgs...], [errs...]}
      # Run both annotations
      mark_nondiscussion msgs
      annotate_stats msgs
      # Now re-write the same file with this included data
      File.open("#{f}", "w") do |fout|
        fout.puts JSON.pretty_generate(jzon)
      end
    rescue => e
      puts "ERROR:scan_dir_json_nondiscussion(#{f}) raised #{e.message[0..255]}"
      errors << "#{e.message}\n\t#{e.backtrace.join("\n\t")}"
      next
    end
  end
  return errors
end

# Aggregate selected header fields from an mbox
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
def scan_dir_headers(dir, ext)
  headers = []
  errs = []
  Dir["#{dir}/**/*#{ext}*".untaint].each do |f|
    headers, errs = scan_mbox_headers(f.untaint, headers)
  end
  annotate_headers(headers)
  return headers
end

# Copied from www/secretary/workbench/models/message.rb
# see https://github.com/mikel/mail/issues/39
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

# Simple header annotations for best guesses of ASF attributes related to trademarks@
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
def do_mbox2csv_hdr(dir)
  headers = scan_dir_headers(dir, MBOX_EXT)
  CSV.open(File.join("#{dir}", "mboxhdr2csv.csv"), "w", headers: %w( date who subject messageid committer question ), write_headers: true) do |csv|
    headers.each do |h|
      csv << [h[:date], h[:who], h[:subject], h[:messageid], h[:committer], h[:type] ]
    end
  end
end

# Combine all jsons of mbox stats into single csv, step by step
# @return [ error1, error2, ...]
def scan_stats_to_csv(dir, outname)
  errors = []
  filenames = Dir["#{dir}/**/*.json".untaint]
  puts "scan_stats_to_csv() processing #{filenames.length} files"
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
      puts "ERROR:parse/write of #{f} raised #{e.message[0..255]}"
      errors << "#{e.message}\n\t#{e.backtrace.join("\n\t")}"
      next
    end
  end
  # TODO ensure files closed?
  return errors
end

# Common use case - analyze mbox files to see how much everyone writes
puts "DEBUG-TESTcsv"
# scan_dir_mbox2stats('/Users/curcuru/src/mail/', MBOX_EXT)
# e = scan_dir_json_nondiscussion('/Users/curcuru/src/mail3/')
# e = fixup_sally_mail('/Users/curcuru/src/mail/')
e = scan_stats_to_csv('/Users/curcuru/src/mail/', 'governance_mboxes2010-2017.csv')
e.each do |x|
  p x
end
puts "DEBUG-END11 e.length #{e.length}"
