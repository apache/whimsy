#
# Process email as it is received
#

#Dir.chdir File.dirname(File.expand_path(__FILE__))

require_relative 'models/mailbox'
require 'mail'
require_relative 'config.rb'

# read and parse email
STDIN.binmode
original = STDIN.read
hash = Message.hash(original)

fail = nil
mailbox = nil

mbox=Mailbox.mboxname(Time.now)  # for mails that don't have the stamp

begin
  mail = Mail.read_from_string(original)
  parts = mail.parts
  subj = mail.subject || ''
  # other methods give to, cc etc as arrays
  # Date is an object, not sure how to ge 
  
  if parts.length == 2 and parts[1].content_type == 'message/rfc822' and subj.start_with? 'MODERATE for '
    hdrs = Mailbox.headers(mail)
    # e.g. Subject: MODERATE for dev@community.apache.org
    list, dom = subj.sub(/^MODERATE for /,'').split'@'
    # e.g. reply-To: dev-accept-1545301944.94902.xxxxxxxx@community.apache.org
    rp = hdrs['Reply-To']
    timestamp = rp[/-(\d+\.\d+)\./, 1]
    headers = {
      allow: hdrs['Cc'], # parser uses these standard names, regardless of input capitalisation
      accept: rp,
      timestamp: timestamp,
      reject: hdrs['From'],
      list: list,
      domain: dom,
      date: hdrs['Date'],
    }
    mbox=Mailbox.mboxname(timestamp.to_f)
    # construct wrapper message
    mailbox = Mailbox.new(mbox)
    # change the hash to change the name of the saved mail
    message = Message.new(mailbox, "#{hash}.orig", nil, original)
    
    # write message to disk
    File.umask(0002)
  #  skip message.write_headers as don't want the headers in a separate file
    message.write_email
    # extract the message for main mailbox
    email = parts[1].body.raw_source
  elsif subj.start_with? 'CONFIRM subscribe to '
    headers = Hash.new
    email = original
  else
    $stderr.puts "Unexpected moderation message in #{hash} with subject: #{subj}"
    headers = Hash.new
    email = original
  end 
  WANTED=%w{Date From To Reply-To Message-ID Subject Return-Path Sender References In-Reply-To}
  headers.merge! Message.parse(email).select{ |k,v| Symbol === k or WANTED.include? k }
rescue => e
  fail = e
  headers = {
    exception: e.to_s,
    backtrace: e.backtrace[0],
    message: 'See procmail.log for full details'
  }
end

# construct message
mailbox = Mailbox.new(mbox) unless mailbox # reuse if exists
message = Message.new(mailbox, hash, headers, email)

# write message to disk
File.umask(0002)
message.write_headers
message.write_email

# Now fail if there was an error
if fail
  require 'time'
  $stderr.puts "WARNING: #{Time.now.utc.iso8601}: error processing email with hash: #{hash}"
  raise fail
end
