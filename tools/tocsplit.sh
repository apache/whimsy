#!/usr/bin/env bash

#  Licensed to the Apache Software Foundation (ASF) under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# Script to invoke tocsplit.rb and check the output
# tocsplit.rb processes agenda/minute file and extracts the Incubator ToCs
# as some were created with more than one copy

FILE=${1:?file to split}
TMPF='/tmp/tocsplit' # Must agree with tocsplit.rb

# Get path to script even if it is a symlink
# N.B. $BASH_SOURCE[0] does not work on macOS High Sierra
DIRNAME=$(dirname $(readlink "$BASH_SOURCE" || echo "$BASH_SOURCE"))

rm -f ${TMPF}*.tmp

$DIRNAME/tocsplit.rb $FILE || exit

# How many files were created?
PARTS=$(ls ${TMPF}*.tmp | wc -l)
ls -l ${TMPF}*.tmp

# Check that the split worked OK (needs bash, not sh)
diff <(cat ${TMPF}*.tmp) $FILE && echo Split worked

if [ $PARTS -eq 5 ] # file start, start of Incubator, ToC*2, rest of file
then
    if diff ${TMPF}10[34].tmp
    then
        echo "Files 103/104 are the same - can drop one of them"
        rm ${TMPF}104.tmp # remove second
        cat ${TMPF}*.tmp > ${FILE}.tmp
        echo Created ${FILE}.tmp with duplicate removed
    else
        echo "ToC sections in $FILE have differences; cannot decide which to drop"
    fi
elif [ $PARTS -eq 4 ]
then
    echo "File $FILE appears to have the correct number of ToC sections"
else
    echo "$FILE has an unexpected number of parts ($PARTS); cannot perform diff"
fi
