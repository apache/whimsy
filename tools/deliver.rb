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

mail = STDIN.read.force_encoding('binary')

# extract info
dest = mail[/^List-Id: <(.*)>/, 1] || mail[/^Delivered-To.* (\S+)\s*$/, 1] || 'unknown'
month = Time.now.strftime('%Y%m')
hash = Digest::SHA1.hexdigest(getmid(mail) || mail)[0..9]

# build file name
file = "#{MAIL_ROOT}/#{dest[/^[-\w]+/]}/#{month}/#{hash}"

File.umask 0002
FileUtils.mkdir_p File.dirname(file)
File.write file, mail, encoding: Encoding::BINARY
File.chmod 0644, file
