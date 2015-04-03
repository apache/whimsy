#
# Refresh agenda from svn server
#

AgendaCache.update(@agenda, nil) {}
_agenda AgendaCache.parse(@agenda, :full)
