# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'
require 'whimsy/asf'

describe ASF::SVN do

  describe "ASF::SVN.repo_entry" do
    it "should return string for 'templates'" do
      res = ASF::SVN.repo_entry('templates')
      expect(res.class).to equal(Hash)
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


  describe "ASF::SVN.svnurl" do
    it "should return URL for 'templates'" do
      res = ASF::SVN.svnurl('templates')
      expect(res.class).to equal(String)
      expect(res).to match(%r{https://.+/templates}) 
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
end