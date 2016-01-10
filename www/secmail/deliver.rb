#
# Process email as it is received
#

Dir.chdir File.dirname(File.expand_path(__FILE__))

require_relative 'models/mailbox'

# read and parse email
STDIN.binmode
email = STDIN.read
hash = Message.hash(email)
headers = Message.parse(email)

# construct message
month = (Time.parse(headers[:time]) rescue Time.now).strftime('%Y%m')
mailbox = Mailbox.new(month)
message = Message.new(mailbox, hash, headers, email)

# write message to disk
message.write_headers
message.write_email
