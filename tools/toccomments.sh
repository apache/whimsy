#!/usr/bin/env bash

# Fix incorrectly wrapped comments in Incubator ToC section
# Intended for use on archived agendas and published minutes.

# Look for Comments: preceeded by non-space
ruby -p -i -e 'gsub(/(\S)\s+(Comments:)/,"\\1\n     \\2")' "$@"
# no need to save original files as tool is intended for use with files in SVN/Git
echo "Done; the updated files can be diffed/checked in as required"