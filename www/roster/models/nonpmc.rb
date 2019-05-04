##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

class NonPMC
  def self.serialize(id, env)
    response = {}

    cttee = ASF::Committee.find(id)
    return unless cttee.nonpmc?
    members = cttee.owners
    committers = cttee.committers
    # Hack to fix unusual mail_list values e.g. press@apache.org
    mail_list = cttee.mail_list.sub(/@.*/,'')
    mail_list = 'legal' if mail_list =~ /^legal-/ unless cttee.name == 'dataprivacy'
    mail_list = 'fundraising' if mail_list =~ /^fundraising-/

    ASF::Committee.load_committee_info
    # We'll be needing the mail data later
    people = ASF::Person.preload(['cn', 'mail', 'asf-altEmail', 'githubUsername'], (members + committers).uniq)

    lists = ASF::Mail.lists(true).select do |list, mode|
      list =~ /^#{mail_list}\b/
    end

    image_dir = ASF::SVN.find('site-img') # Probably not relevant to nonPMCS; leave for now
    image = Dir[File.join(image_dir, "#{id}.*")].map {|path| File.basename(path)}.last

    moderators = nil
    modtime = nil
    subscribers = nil # we get the counts only here
    subtime = nil
    pSubs = Array.new # private@ subscribers
    unMatchedSubs = [] # unknown private@ subscribers
    unMatchedSecSubs = [] # unknown security@ subscribers
    currentUser = ASF::Person.find(env.user)
    # Might make sense for non-PMCs - remove the code later if not
    analysePrivateSubs = false # whether to show missing private@ subscriptions
    if cttee.roster.include? env.user or currentUser.asf_member?
      require 'whimsy/asf/mlist'
      moderators, modtime = ASF::MLIST.list_moderators(mail_list)
      subscribers, subtime = ASF::MLIST.list_subscribers(mail_list) # counts only
      analysePrivateSubs = currentUser.asf_member?
      unless analysePrivateSubs # check for private moderator if not already allowed access
        user_mail = currentUser.all_mail || []
        pMods = moderators["private@#{mail_list}.apache.org"] || []
        analysePrivateSubs = !(pMods & user_mail).empty?
      end
      if analysePrivateSubs
        pSubs = ASF::MLIST.private_subscribers(mail_list)[0]||[]
        unMatchedSubs=Set.new(pSubs) # init ready to remove matched mails
        pSubs.map!{|m| m.downcase} # for matching
        sSubs = ASF::MLIST.security_subscribers(mail_list)[0]||[]
        unMatchedSecSubs=Set.new(sSubs) # init ready to remove matched mails
      end
    else
      lists = lists.select {|list, mode| mode == 'public'}
    end

    roster = cttee.roster.dup
    # if the roster is empty, then add the chair(s)
    if roster.empty?
      cttee.chairs.each do |ch|
        roster[ch[:id]] = {name: ch[:name], date: 'uknown'} # it is used to flag CI data so must be true in Javascript
      end
    end
    cttee_members = roster.keys # get the potentially updated list

    # now add the status info 
    roster.each {|key, info| info[:role] = 'Committee member'}

    members.each do |person|
      roster[person.id] ||= {
        name: person.public_name, 
        role: 'Committee member'
      }
      if analysePrivateSubs
        allMail = person.all_mail.map{|m| m.downcase}
        roster[person.id]['notSubbed'] = (allMail & pSubs).empty?
        unMatchedSubs.delete_if {|k| allMail.include? k.downcase}
        unMatchedSecSubs.delete_if {|k| allMail.include? k.downcase}
      end
      roster[person.id]['ldap'] = true
      roster[person.id]['githubUsername'] = (person.attrs['githubUsername'] || []).join(', ')
    end

    committers.each do |person|
      roster[person.id] ||= {
        name: person.public_name,
        role: 'Committer'
      }
      roster[person.id]['githubUsername'] = (person.attrs['githubUsername'] || []).join(', ')
    end

    roster.each {|id, info| info[:member] = ASF::Person.find(id).asf_member?}

    if cttee.chair and roster[cttee.chair.id]
      roster[cttee.chair.id]['role'] = 'Committee chair' 
    end

    # separate out the known ASF members and extract any matching committer details
    unknownSubs = [] # unknown private@ subscribers: not PMC or ASF
    asfMembers = []
    unknownSecSubs = [] # unknown security@ subscribers: not PMC or ASF
    # Also look for non-ASF mod emails
    nonASFmails=Hash.new
    if moderators
      moderators.each { |list,mods| mods.each {|m| nonASFmails[m]='' unless m.end_with? '@apache.org'} }
    end
    if unMatchedSubs.length > 0 or nonASFmails.length > 0 or unMatchedSecSubs.length > 0
      load_emails # set up @people
      unMatchedSubs.each{ |addr|
        who = nil
        @people.each do |person|
          if person[:mail].any? {|mail| mail.downcase == addr.downcase}
            who = person
          end
        end
        if who
          if who[:member]
            asfMembers << { addr: addr, person: who }
          else
            unknownSubs << { addr: addr, person: who }
          end
        else
          unknownSubs << { addr: addr, person: nil }
        end
      }
      nonASFmails.each {|k,v|
        @people.each do |person|
          if person[:mail].any? {|mail| mail.downcase == k.downcase}
            nonASFmails[k] = person[:id]
          end
        end
      }
      unMatchedSecSubs.each{ |addr|
        who = nil
        @people.each do |person|
          if person[:mail].any? {|mail| mail.downcase == addr.downcase}
            who = person
          end
        end
        if who
          unless who[:member]
            unknownSubs << { addr: addr, person: who }
          end
        else
          unknownSecSubs << { addr: addr, person: nil }
        end
      }
    end

    response = {
      id: id,
      chair: cttee.chair && cttee.chair.id,
      display_name: cttee.display_name,
      description: cttee.description,
      schedule: cttee.schedule,
      report: cttee.report,
      site: cttee.site,
      established: cttee.established,
      ldap: members.map(&:id),
      members: cttee_members,
      committers: committers.map(&:id),
      roster: roster,
      mail: Hash[lists.sort],
      moderators: moderators,
      modtime: modtime,
      subscribers: subscribers,
      subtime: subtime,
      nonASFmails: nonASFmails,
      image: image,
      analysePrivateSubs: analysePrivateSubs,
      unknownSubs: unknownSubs,
      asfMembers: asfMembers,
      unknownSecSubs: unknownSecSubs,
    }

    response
  end

  private

  def self.load_emails
    # recompute index if the data is 5 minutes old or older
    @people = nil if not @people_time or Time.now-@people_time >= 300
  
    if not @people
      # bulk loading the mail information makes things go faster
      mail = Hash[ASF::Mail.list.group_by(&:last).
        map {|person, list| [person, list.map(&:first)]}]
  
      # build a list of people, their public-names, and email addresses
      @people = ASF::Person.list.map {|person|
        result = {id: person.id, name: person.public_name, mail: mail[person]}
        result[:member] = true if person.asf_member?
        result
      }

      # cache
      @people_time = Time.now
    end
    @people
  end

end
