#!/usr/bin/env bash

# Fix incorrectly wrapped comments in Incubator ToC section

# Look for Comments: preceeded by non-space
ruby -p -i.orig -e 'gsub(/(\S)\s+(Comments:)/,"\\1\n     \\2")' "$@"
for i in "$@"
do
  # if the files are the same, drop the unchanged output
  if cmp -s $i $i.orig
  then
      echo "$i has not changed"
      rm $i.orig
  else
      echo "$i has changed"
#       ls -l $i*
  fi
done
