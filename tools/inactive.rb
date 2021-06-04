#!/usr/bin/env ruby

$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'

ASF::Person.preload(%w(uid))
cttees = ASF::Committee.load_committee_info
cttees.each do |cttee|
  cttee.info.each do |availid|
    person = ASF::Person[availid]
    if person.asf_member?.to_s.start_with? 'Deceased'
      p [cttee.name,availid,person.asf_member?]
    end
  end
end