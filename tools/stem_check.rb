#!/usr/bin/env ruby

# @(#) DRAFT: scan iclas.txt and check if stem method agrees with file names

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
