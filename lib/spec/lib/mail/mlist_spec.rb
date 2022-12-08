# encoding: utf-8
# frozen_string_literal: true

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

require 'spec_helper'
require 'whimsy/asf'
require 'whimsy/asf/mlist' # not loaded by default

describe ASF::MLIST do

  describe "ASF::MLIST.members_subscribers" do
    it "should return an array of members@ subscribers followed by the file update time" do
      res = ASF::MLIST.members_subscribers()
      expect(res.class).to eq(Array)
      expect(res.length).to eq(2)
      subs, stamp = res
      expect(subs.class).to eq(Array)
      expect(stamp.class).to eq(Time)
      if TEST_DATA
        expect(subs.length).to be_between(1, 10).inclusive
      else
        expect(subs.length).to be_between(500, 1000).inclusive
      end
    end
  end

  describe "ASF::MLIST.list_archivers" do
    it "should return array of form [dom, list, [[archiver, type, alias|direct],...]" do
      ASF::MLIST.list_archivers do |res|
        expect(res.class).to eq(Array)
        expect(res.length).to eq(3)
        dom, list, arches = res # unpack
        expect(dom.class).to eq(String)
        expect(list.class).to eq(String)
        expect(arches.class).to eq(Array)
        arches.each do |arch|
          expect(arch.length).to eq(3)
        end
      end
    end
  end

  describe "ASF::MLIST.moderates(user_emails, response)" do
    it "should not find any entries for invalid emails" do
      user_emails = ['user@localhost', 'user@domain.invalid']
      res = ASF::MLIST.moderates(user_emails)
      expect(res.length).to eq(2)
      mods = res[:moderates]
      expect(mods.length).to eq(0)
    end

    it "should find some entries for mod-private@gsuite.cloud.apache.org" do
      user_emails = ['mod-private@gsuite.cloud.apache.org']
      res = ASF::MLIST.moderates(user_emails)
      expect(res.length).to eq(2)
      mods = res[:moderates]
      expect(mods.length).to be_between(7, 20)
    end
  end

  describe "ASF::MLIST.subscriptions(user_emails, response)" do
    it "should not find any entries for invalid emails" do
      user_emails = ['user@localhost', 'user@domain.invalid']
      res = ASF::MLIST.subscriptions(user_emails)
      expect(res.length).to eq(2)
      mods = res[:subscriptions]
      expect(mods.length).to eq(0)
    end
  end

  it "should find lots of entries for archiver@mbox-vm.apache.org" do
    user_emails = ['archiver@mbox-vm.apache.org']
    res = ASF::MLIST.subscriptions(user_emails)
    expect(res.length).to eq(2)
    mods = res[:subscriptions]
    if TEST_DATA
      expect(mods.length).to be_between(10, 20)
    else
      expect(mods.length).to be_between(1000, 1250)
    end
  end

  describe "ASF::MLIST.each_list" do
    it "should return an array of form [[dom, list],...]" do
      ASF::MLIST.each_list do |res|
        expect(res.class).to eq(Array)
        expect(res.length).to eq(2)
        dom, list = res # unpack
        expect(dom.class).to eq(String)
        expect(list.class).to eq(String)
        expect(dom).to match(/^[a-z.0-9-]+\.[a-z]+$/)
        next if list == 'commits.deprecated' # allow for unusual list name
        expect(list).to match(/^[a-z0-9-]+$/)
      end
    end
  end

  describe "ASF::MLIST.list_subscribers(mail_domain, podling=false, list_subs=false, skip_archivers=false)" do
    it "abcd should return an array of the form [Hash, Time]" do
      res = ASF::MLIST.list_subscribers('abcd')
      # array of Hash and Updated date
      expect(res.class).to eq(Array)
      expect(res.length).to eq(2)
      list, stamp = res
      expect(list.class).to eq(Hash)
      expect(stamp.class).to eq(Time)
      expect(list.size).to eq(0)
    end
    it "members should have some entries" do
      list, _ = ASF::MLIST.list_subscribers('members')
      if TEST_DATA
        expect(list.size).to eq(1) # members
        expect(list.keys.first).to eq('members@apache.org')
      else
        expect(list.size).to eq(3) # members, members-announce and members-notify
        expect(list.keys[0]).to eq('members@apache.org')
        expect(list.keys[1]).to eq('members-announce@apache.org')
        expect(list.keys[2]).to eq('members-notify@apache.org')
      end
    end
  end
  describe "ASF::MLIST.list_moderators(mail_domain, podling=false)" do
    it "abcd should return an array of the form [Hash, Time]" do
      res = ASF::MLIST.list_moderators('abcd')
      # array of Hash and Updated date
      expect(res.class).to eq(Array)
      expect(res.length).to eq(2)
      list, stamp = res
      expect(list.class).to eq(Hash)
      expect(stamp.class).to eq(Time)
      expect(list.size).to eq(0)
    end
    it "members should have some entries" do
      list, _ = ASF::MLIST.list_moderators('members')
      if TEST_DATA
        expect(list.size).to eq(1) # members
        expect(list.keys.first).to eq('members@apache.org')
        entry = list.first
        expect(entry.class).to eq(Array)
        expect(entry.size).to eq(2)
        expect(entry[1].size).to eq(1) # number of moderators
      else
        expect(list.size).to eq(3) # members, members-announce and members-notify
        expect(list.keys[0]).to eq('members@apache.org')
        expect(list.keys[1]).to eq('members-announce@apache.org')
        expect(list.keys[2]).to eq('members-notify@apache.org')
        entry = list.first
        expect(entry.class).to eq(Array)
        expect(entry.size).to eq(2)
        expect(entry[1].size).to be_between(2, 5).inclusive # number of moderators
      end
    end
  end
end
