#!/usr/bin/env bash

# Script to invoke tocsplit.rb and check the output
# tocsplit.rb processes agenda/minute file and extracts the Incubator ToCs
# as some were created with more than one copy

FILE=${1:?file to split}
TMPF='/tmp/tocsplit' # Must agree with tocsplit.rb

# Get path to script even if it is a symlink
# N.B. $BASH_SOURCE[0] does not work on macOS High Sierra
DIRNAME=$(dirname $(readlink "$BASH_SOURCE" || echo "$BASH_SOURCE"))

rm -f ${TMPF}*.tmp

$DIRNAME/tocsplit.rb $1 || exit

# How many files were created?
PARTS=$(ls ${TMPF}*.tmp | wc -l)
ls -l ${TMPF}*.tmp

# Check that the split worked OK (needs bash, not sh)
diff <(cat ${TMPF}*.tmp) $1 && echo Split worked

if [ $PARTS -eq 5 ] # file start, start of Incubator, ToC*2, rest of file
then
    diff ${TMPF}10[34].tmp && echo "Files 103/104 are the same - can drop one of them"
elif [ $PARTS -eq 4 ]
then
    echo "File appears to have the correct number of ToC sections"
else
    echo "Unexpected number of parts ($PARTS); cannot perform diff"
fi
