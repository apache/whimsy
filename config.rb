#
# Where to find the archive
#

SOURCE = 'minotaur.apache.org:/home/apmail/private-arch/officers-secretary'

#
# Where to save the archive locally
#

ARCHIVE = File.basename(SOURCE)

#
# What to use as a hash for mail
#
require 'digest'
def hashmail(message)
  Digest::SHA1.hexdigest(mail[/^Message-ID:.*/i] || mail)[0..9]
end

