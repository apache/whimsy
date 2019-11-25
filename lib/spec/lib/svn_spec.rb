# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'
require 'whimsy/asf'

describe ASF::SVN do
  
  # repo_entry should only include repos that have local workspaces
  
  describe "ASF::SVN.repo_entry" do
    it "should return string for 'templates'" do
      res = ASF::SVN.repo_entry('templates')
      expect(res.class).to equal(Hash)
    end

    it "should return nil for 'Bills'" do
      res = ASF::SVN.repo_entry('Bills')
      expect(res.class).to equal(NilClass)
    end

    it "should return nil for '__templates'" do
      res = ASF::SVN.repo_entry('__templates')
      expect(res.class).to equal(NilClass)
    end

  end

  describe "ASF::SVN.repo_entry!" do
    it "should return string for 'templates'" do
      res = ASF::SVN.repo_entry!('templates')
      expect(res.class).to equal(Hash)
    end

    it "should fail for '__templates'" do
      expect{
        ASF::SVN.repo_entry!('__templates')
      }.to raise_error(Exception)
    end

  end

  # svnurl should include aliases

  describe "ASF::SVN.svnurl" do
    it "should return URL for 'templates'" do
      res = ASF::SVN.svnurl('templates')
      expect(res.class).to equal(String)
      expect(res).to match(%r{https://.+/templates}) 
    end
  
    it "should return URL for 'Bills'" do
      res = ASF::SVN.svnurl('Bills')
      expect(res.class).to equal(String)
      expect(res).to match(%r{https://.+/Bills}) 
    end
  
    it "should return nil for '__templates'" do
      res = ASF::SVN.svnurl('__templates')
      expect(res.class).to equal(NilClass)
    end
  
  end

  describe "ASF::SVN.svnurl!" do
    it "should return URL for 'templates'" do
      res = ASF::SVN.svnurl!('templates')
      expect(res.class).to equal(String)
      expect(res).to match(%r{https://.+/templates}) 
    end
  
    it "should fail for '__templates'" do
      expect {
        ASF::SVN.svnurl!('__templates')
      }.to raise_error(Exception)
    end
  
  end

  # repo_entries should exclude aliases

  describe "ASF::SVN.repo_entries" do
    it "should return hash with templates but not Bills" do
      res = ASF::SVN.repo_entries
      expect(res.class).to equal(Hash)
      expect(res['templates'].class).to equal(Hash)
      expect(res['Bills']).to equal(nil)
    end
    
  end

  # find returns local workspace so excludes aliases

  describe "ASF::SVN.find" do
    it "should return string for 'templates'" do
      res = ASF::SVN.find('templates')
      expect(res.class).to equal(String)
    end
  
    it "should return nil for 'Bills'" do
      res = ASF::SVN.find('Bills')
      expect(res.class).to equal(NilClass)
    end
  
    it "should return nil for '__templates'" do
      res = ASF::SVN.find('__templates')
      expect(res.class).to equal(NilClass)
    end
  
  end

end