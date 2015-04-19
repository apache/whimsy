#
# Refresh agenda from svn server
#

# update the entire board directory
_.system ['svn', 'update', FOUNDATION_BOARD]

# return a parsed version of the agenda in question
AgendaCache.update(@agenda, nil) {}
