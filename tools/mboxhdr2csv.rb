#!/usr/bin/env ruby
# Analyze mbox files (downloaded by PonyAPI) for general statistics into CSV
# - Per list messages per month over time (PMOT)
# - Count messages group by list -> graph months as time
# - Per list contentlines per lists PMOT
# - Per user statistics
# Count lines of text content in mail body, roughly attempting to
#   count just new content (not automated, not > replies)
# Attempt to normalize/map email addresses to committer/member status

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
require 'mail'
require 'csv'
require 'stringio'
require 'zlib'
require 'json'
require 'date'
require 'optparse'

# Various utility functions/data for mailing list analysis
module MailUtils
  extend self
  MEMBER = 'member'
  COMMITTER = 'committer'
  COUNSEL = 'counsel'
  INVALID = '.INVALID'
  DATE = 'date'
  FROM = 'from'
  WHO = 'who'
  AVAILID = 'id'
  SUBJECT = 'subject'
  TOOLS = 'tools'
  MAILS = 'mails'
  TOOLCOUNT = 'toolcount'
  MAILCOUNT = 'mailcount'

  # Subject regexes that are non-discussion oriented
  # Analysis: don't bother with content lines in these messages,
  #   because most of the content is tool-generated
  NONDISCUSSION_SUBJECTS = { # Note: none applicable to members@
    '<board.apache.org>' => {
      missing: /\AMissing\s((\S+\s){1,3})Board/, # whimsy/www/board/agenda/views/buttons/email.js.rb
      feedback: /\ABoard\sfeedback\son\s20/, # whimsy/www/board/agenda/views/actions/feedback.json.rb
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

  # Annotate mailhash by adding :who and :committer (where known)
  # @param mdata Hash to evaluate and annotate
  # Side effect: adds :who, :committer, :id from ASF::Person.find_by_email
  # :committer = 'n' if not found; 'N' if error, 'counsel' for special case
  def find_who_from(mdata)
    # Remove bogus INVALID before doing lookups
    from = mdata[:from].sub(INVALID, '')
    # Micro-optimize unique names
    case from
    when /Mark.Radcliffe/i
      mdata[:who] = 'Mark.Radcliffe'
      mdata[:committer] = COUNSEL
      mdata[:id] = 'markfradcliffe'
    when /mattmann/i
      mdata[:who] = 'Chris Mattmann'
      mdata[:committer] = MEMBER
      mdata[:id] = 'mattmann'
    when /jagielski/i
      mdata[:who] = 'Jim Jagielski'
      mdata[:committer] = MEMBER
      mdata[:id] = 'jim'
    when /delacretaz/i
      mdata[:who] = 'Bertrand Delacretaz'
      mdata[:committer] = MEMBER
      mdata[:id] = 'bdelacretaz'
    when /curcuru/i
      mdata[:who] = 'Shane Curcuru'
      mdata[:committer] = MEMBER
      mdata[:id] = 'curcuru'
    when /steitz/i
      mdata[:who] = 'Phil Steitz'
      mdata[:committer] = MEMBER
      mdata[:id] = 'psteitz'
    when /gardler/i  # Effectively unique (see: Heidi)
      mdata[:who] = 'Ross Gardler'
      mdata[:committer] = MEMBER
      mdata[:id] = 'rgardler'
    when /Craig (L )?Russell/i # Optimize since Secretary sends a lot of mail
      mdata[:who] = 'Craig L Russell'
      mdata[:committer] = MEMBER
      mdata[:id] = 'clr'
    when /McGrail/i
      mdata[:who] = 'Kevin A. McGrail'
      mdata[:committer] = MEMBER
      mdata[:id] = 'kmcgrail'
    when /sallykhudairi@yahoo/i
      mdata[:who] = 'Sally Khudairi'
      mdata[:committer] = MEMBER
      mdata[:id] = 'sk'
    when /sk@haloworldwide.com/i
      mdata[:who] = 'Sally Khudairi'
      mdata[:committer] = MEMBER
      mdata[:id] = 'sk'
    else
      begin
        # TODO use Real Name (JIRA) to attempt to lookup some notifications
        tmp = liberal_email_parser(from)
        person = ASF::Person.find_by_email(tmp.address.dup)
        if person
          mdata[:who] = person.cn
          mdata[:id] = person.id
          if person.asf_member?
            mdata[:committer] = MEMBER
          else
            mdata[:committer] = COMMITTER
          end
        else
          mdata[:who] = "#{tmp.display_name} <#{tmp.address}>"
          mdata[:committer] = 'n'
          mdata[:id] = 'unknown'
        end
      rescue
        mdata[:who] = mdata[:from] # Use original value here
        mdata[:committer] = 'N'
        mdata[:id] = 'unknown'
      end
    end
  end

  # Get {MAILS: [{date, who, subject, flag},...\, TOOLS: [{...},...] } from the specified list for a month
  # May cache data in mailroot/yearmonth.json
  # Returns empty hash if error or if can't find month
  def get_mails_month(mailroot:, yearmonth:, nondiscuss:)
    # Return cached calculated data if present
    cache_json = File.join(mailroot, "#{yearmonth}.json")
    if File.file?(cache_json)
      begin
        return JSON.parse(File.read(cache_json))
      rescue StandardError => _e
        # No-op: fall through to attempt to re-create cache
      end
    end
    emails = {}
    files = Dir[File.join(mailroot, yearmonth, '*')]
    return emails if files.empty?
    emails[MAILS] = []
    emails[TOOLS] = []
    files.each do |email|
      next if email.end_with? '/index'
      message = IO.read(email, mode: 'rb')
      data = {}
      data[DATE] = DateTime.parse(message[/^Date: (.*)/, 1]).iso8601
      data[FROM] = message[/^From: (.*)/, 1]
      # Originally (before 2265343) the local method #find_who_from expected an email address and returned who, committer
      # Emulate this with the version from MailUtils which expects and updates a hash
      temp = {from: data[FROM]} # pass a hash
      MailUtils.find_who_from(temp) # update the hash
      # pick out the bits we want
      data[WHO], data[COMMITTER], data[AVAILID] = temp[:who], temp[:committer], temp[:id]

      data[SUBJECT] = message[/^Subject: (.*)/, 1]
      if nondiscuss
        nondiscuss.each do |typ, rx|
          if data[SUBJECT] =~ rx
            data[TOOLS] = typ
            break # regex.each
          end
        end
      end
      data.has_key?(TOOLS) ? emails[TOOLS] << data : emails[MAILS] << data
    end
    # Provide as sorted data for ease of use
    emails[TOOLS].sort_by! { |email| email[DATE] }
    emails[TOOLCOUNT] = Hash.new {|h, k| h[k] = 0 }
    emails[TOOLS].each do |mail|
      emails[TOOLCOUNT][mail[TOOLS]] += 1
    end
    emails[TOOLCOUNT] = emails[TOOLCOUNT].sort_by { |_k, v| -v}.to_h

    emails[MAILS].sort_by! { |email| email[DATE] }
    emails[MAILCOUNT] = Hash.new {|h, k| h[k] = 0 }
    emails[MAILS].each do |mail|
      emails[MAILCOUNT]["#{mail[WHO]} (#{mail[AVAILID]})"] += 1
    end
    emails[MAILCOUNT] = emails[MAILCOUNT].sort_by { |_k, v| -v}.to_h

    # If yearmonth is before current month, then write out yearmonth.json as cache
    if yearmonth < Date.today.strftime('%Y%m')
      begin
        File.open(cache_json, 'w') do |f|
          f.puts JSON.pretty_generate(emails)
        end
      rescue
        # No-op, just don't cache for now
      end
    end
    return emails
  end
end

module MboxUtils
  extend self
  MBOX_EXT = '.mbox'
  VERSION = 'mboxhdr2json'
  URIRX = URI.regexp(['http', 'https'])

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
        rescue => _e
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
        links = 0 # Count number of apparent hyperlinks
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
            # TODO: figure out if we're in a .sig block, and stop counting
          else
            links += 1 if l =~ URIRX
            ctr += 1
          end
        end
        mdata[:lines] = ctr
        mdata[:links] = links
        # Annotate various other precomputable data
        MailUtils.find_who_from(mdata)
        begin
          d = DateTime.parse(mdata[:date])
          mdata[:y] = d.year
          mdata[:m] = d.month
          mdata[:d] = d.day
          mdata[:w] = d.wday
          mdata[:h] = d.hour
          mdata[:z] = d.zone
        rescue => _e
          # no-op - not critical
          puts "DEBUG: #{e.message} parsing: #{mdata[:date]}"
        end
        regex = MailUtils::NONDISCUSSION_SUBJECTS[mdata[:listid]] # Use subject regex for this list (if any)
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

  # Scan dir tree for mboxes and output individual mailhash as JSONs
  # @param dir to scan (whole tree)
  # @param ext file extension to glob for
  # Side effect: writes out f.chomp(ext).json files
  # @note writes string VERSION for differentiating from other *.json
  def scan_dir_mbox2stats(dir, ext = MBOX_EXT)
    Dir[File.join(dir, "**", "*#{ext}")].sort.each do |f|
      mails, errs = mbox2stats(f)
      File.open("#{f.chomp(ext)}.json", "w") do |fout|
        fout.puts JSON.pretty_generate([VERSION, mails, errs])
      end
    end
  end

  # Scan dir tree for mailhash JSONs and output an overview CSV of all
  # @return [ error1, error2, ...] if any errors
  # Side effect: writes out dir/outname CSV file
  # @note reads string VERSION for differentiating from other *.json
  def scan_dir_stats2csv(dir, outname, ext = '.json')
    errors = []
    jzons = []
    Dir[File.join(dir, "**", "*#{ext}")].sort.each do |f|
      begin
        tmp = JSON.parse(File.read(f))
        if tmp[0].kind_of?(String) && tmp[0].start_with?(VERSION)
          jzons << tmp.drop(1)
        end
      rescue => e
        puts "ERROR: parse of #{f} raised #{e.message[0..255]}"
        errors << "#{e.message}\n\t#{e.backtrace.join("\n\t")}"
        next
      end
    end
    raise ArgumentError, "#{__method__} called with no valid mbox json files in #{dir}" if jzons.length == 0
    puts "#{__method__} processing #{jzons.length} mbox json files"
    # Write out headers and the first array in new csv
    csvfile = File.join(dir, outname)
    csv = CSV.open(csvfile, "w", headers: %w( year month day weekday hour zone listid who subject lines links committer messageid inreplyto ), write_headers: true)
    jzons.shift[0].each do |m|
      csv << [ m['y'], m['m'], m['d'], m['w'], m['h'], m['z'], m['listid'], m['who'], m['subject'], m['lines'], m['links'], m['committer'], m['messageid'], m['inreplyto']  ]
    end
    # Write out all remaining arrays, without headers, appending
    jzons.each do |j|
      begin
        j[0].each do |m|
          csv << [ m['y'], m['m'], m['d'], m['w'], m['h'], m['z'], m['listid'], m['who'], m['subject'], m['lines'], m['links'], m['committer'], m['messageid'], m['inreplyto']  ]
        end
      rescue => e
        puts "ERROR: write of #{f} raised #{e.message[0..255]}"
        errors << "#{e.message}\n\t#{e.backtrace.join("\n\t")}"
        next
      end
    end
    csv.close # Just in case
    return errors
  end
end

# ## ### #### ##### ######
# Check options and call needed methods
DEFAULT_OUTPUT = 'mbox-analysis.csv'
def optparse
  options = {}
  OptionParser.new do |opts|
    opts.on('-h') { puts opts; exit }

    opts.on('-dDIRECTORY', '--directory DIRECTORY', 'Local directory to read existing mboxes and dump output in (default: .)') do |d|
      if File.directory?(d)
        options[:dir] = d
      else
        raise ArgumentError, "-d #{d} is not a valid directory"
      end
    end
    opts.on('-oOUTPUT.CSV', '--output OUTPUT.CSV', "Filename to output rows into; default #{DEFAULT_OUTPUT}") do |o|
      options[:output] = o
    end
    opts.on('-j', '--json', "Process .mbox to .json (optional)") do
      options[:json] = true
    end
    begin
      opts.parse!
      options[:dir] = '.' if options[:dir].nil?
      options[:output] = DEFAULT_OUTPUT if options[:output].nil?
    rescue StandardError => e
      $stderr.puts "#{e.message}; try -h for valid options, or see code"
      exit 1
    end
  end

  return options
end

# ## ### #### ##### ######
# Main method for command line use
if __FILE__ == $PROGRAM_NAME
  options = optparse
  if options[:json]
    puts "START: Parsing #{options[:dir]}/*#{MboxUtils::MBOX_EXT} into *.json"
    MboxUtils.scan_dir_mbox2stats(options[:dir]) # Side effect: writes out f.chomp(ext).json files
  end
  puts "START: Analyzing #{options[:dir]}/*.json into #{options[:output]}"
  errs = MboxUtils.scan_dir_stats2csv(options[:dir], options[:output])
  if errs
    errs.each do |e|
      puts "ERROR: #{e}"
    end
  end
  puts "END"
end
