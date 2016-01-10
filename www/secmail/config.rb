#
# Where to find the archive
#

SOURCE = 'minotaur.apache.org:/home/apmail/private-arch/officers-secretary'

#
# Where to save the archive locally
#

ARCHIVE = (Dir.exist?('/srv/mail') ? '/srv/mail' : File.basename(SOURCE))

