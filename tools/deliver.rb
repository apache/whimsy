#
# Receive and deliver mail
#

require 'digest'
require 'fileutils'

MAIL_ROOT = '/srv/mail'

# get the message ID
def self.getmid(hdrs)
  mid = hdrs[/^Message-ID:.*/i]
  if mid =~ /^Message-ID:\s*$/i # no mid on the first line
    # capture the next line and join them together
    # line may also start with tab; we don't use \s as this also matches EOL
    # Rescue is in case we don't match properly - we want to return nil in that case
    mid = hdrs[/^Message-ID:.*\r?\n[ \t].*/i].sub(/\r?\n/,'') rescue nil
  end
  mid
end

STDIN.binmode
mail = STDIN.read

# only search headers for MID and List-ID etc
hdrs = mail[/\A(.*?)\r?\n\r?\n/m, 1] || ''

# extract info
dest = hdrs[/^List-Id: <(.*)>/, 1] || hdrs[/^Delivered-To.* (\S+)\s*$/, 1] || 'unknown'
list = dest[/^[-\w]+/]
month = Time.now.strftime('%Y%m')
hash = Digest::SHA1.hexdigest(getmid(hdrs) || mail)[0..9]

# build file name
filedir = File.join(MAIL_ROOT, list, month)
file = File.join(filedir, hash)

File.umask 0o002
FileUtils.mkdir_p filedir
File.write file, mail, encoding: Encoding::BINARY
File.chmod 0o644, file
