# encoding: utf-8
# frozen_string_literal: true
require 'spec_helper'
require 'whimsy/asf'
require 'whimsy/asf/mlist' # not loaded by default

describe ASF::MLIST do

  describe "Dummy test to trigger Travis error" do
    it "Should fail" do
      expect(%x(ls /srv)).to eq('')      
    end
  end

  describe "ASF::MLIST.members_subscribers" do
    it "should return an array of members@ subscribers followed by the file update time", :skip => TEST_DATA do
      res = ASF::MLIST.members_subscribers()
      expect(res.class).to eq(Array)
      expect(res.length).to eq(2)
      subs,stamp = res
      expect(subs.class).to eq(Array)
      expect(stamp.class).to eq(Time)
      expect(subs.length).to be_between(500, 1000).inclusive
    end
  end

  describe "ASF::MLIST.list_archivers" do
    it "should return array of form [dom, list, [[archiver, type, alias|direct],...]", :skip => TEST_DATA do
      ASF::MLIST.list_archivers do |res|
        expect(res.class).to eq(Array)
        expect(res.length).to eq(3)
        dom,list,arches = res # unpack
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
    it "should not find any entries for invalid emails", :skip => TEST_DATA do
      user_emails=['user@localhost', 'user@domain.invalid']
      res = ASF::MLIST.moderates(user_emails)
      expect(res.length).to eq(2)
      mods = res[:moderates]
      expect(mods.length).to eq(0)
    end

    it "should find some entries for mod-private@gsuite.cloud.apache.org", :skip => TEST_DATA do
      user_emails=['mod-private@gsuite.cloud.apache.org']
      res = ASF::MLIST.moderates(user_emails)
      expect(res.length).to eq(2)
      mods = res[:moderates]
      expect(mods.length).to be_between(8, 20)
    end
  end

  describe "ASF::MLIST.subscriptions(user_emails, response)" do
    it "should not find any entries for invalid emails", :skip => TEST_DATA do
      user_emails=['user@localhost', 'user@domain.invalid']
      res = ASF::MLIST.subscriptions(user_emails)
      expect(res.length).to eq(2)
      mods = res[:subscriptions]
      expect(mods.length).to eq(0)
    end
  end

  it "should find lots of entries for archiver@mbox-vm.apache.org", :skip => TEST_DATA do
    user_emails=['archiver@mbox-vm.apache.org']
    res = ASF::MLIST.subscriptions(user_emails)
    expect(res.length).to eq(2)
    mods = res[:subscriptions]
    expect(mods.length).to be_between(1000, 1200)
  end

  describe "ASF::MLIST.each_list" do
    it "should return an array of form [[dom, list],...]", :skip => TEST_DATA do
      ASF::MLIST.each_list do |res|
        expect(res.class).to eq(Array)
        expect(res.length).to eq(2)
        dom,list = res # unpack
        expect(dom.class).to eq(String)
        expect(list.class).to eq(String)
        expect(dom).to match(/^[a-z.0-9-]+\.[a-z]+$/)
        expect(list).to match(/^[a-z0-9-]+$/)
      end
    end
  end

end
