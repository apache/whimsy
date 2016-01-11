#
# Where to find the archive
#

SOURCE = 'minotaur.apache.org:/home/apmail/private-arch/officers-secretary'

#
# Where to save the archive locally
#

ARCHIVE = (Dir.exist?('/srv/mail') ? '/srv/mail' : File.basename(SOURCE))

#
# GPG's work directory override
#

GNUPGHOME = (Dir.exist?('/srv/gpg') ? '/srv/gpg' : nil)
