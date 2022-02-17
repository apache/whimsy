#!/usr/bin/env ruby

# @(#) DRAFT: scan iclas.txt and check if stem method agrees with file names

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

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'

legal = 0 # matches converted legal name
public = 0 # matches converted public name
invalid = 0 # no match

ASF::ICLA.each do |icla|
    claRef = icla.claRef
    next unless claRef
    lstem = ASF::Person.stem_DRAFT icla.legal_name
    pstem = ASF::Person.stem_DRAFT icla.name
    if lstem == claRef
       legal += 1
    elsif pstem == claRef
       public += 1
    else
       p [claRef, lstem, pstem, icla.legal_name, icla.name]
       invalid += 1
    end
end
p [legal,public, invalid]
