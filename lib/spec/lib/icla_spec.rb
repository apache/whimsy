# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'
require 'whimsy/asf'

# Test data:
# ab/        abc.pdf     abcd/    abcde/
# N.B. does not make sense for top-level directory to contain more than 1 entry with same stem;
# in such cases the files are moved to a subdirectory

describe ASF::ICLAFiles do
  original = nil
  before(:all) do
    original = set_cache # need access to listing file
  end
  after(:all) do
    set_cache(original)
  end
  describe "ASF::ICLAFiles.listnames" do
    it "should return 4 files" do
      res = ASF::ICLAFiles.listnames
      expect(res.length).to equal(4)
    end
  end

  describe "ASF::ICLAFiles.matchStem" do
    it "should return [] for abcd" do
      res = ASF::ICLAFiles.matchStem('abcd')
      expect(res).to eq([])
    end
    it "should return [abc.pdf] for abc" do
      res = ASF::ICLAFiles.matchStem('abc')
      expect(res).to eq(['abc.pdf'])
    end
  end

  describe "ASF::ICLAFiles.Dir?" do
    it "should return true for ab" do
      res = ASF::ICLAFiles.Dir?('ab')
      expect(res).to eq(true)
    end
    it "should return false for abc" do
      res = ASF::ICLAFiles.Dir?('abc')
      expect(res).to eq(false)
    end
    it "should return true for abcd" do
      res = ASF::ICLAFiles.Dir?('abcd')
      expect(res).to eq(true)
    end
    it "should return true for abcde" do
      res = ASF::ICLAFiles.Dir?('abcde')
      expect(res).to eq(true)
    end
  end

  describe "ASF::ICLAFiles.match_claRef" do
    it "should return nil for 'xyz'" do
      res = ASF::ICLAFiles.match_claRef('xyz')
      expect(res).to equal(nil)
    end
    it "should return nil for 'a'" do
      res = ASF::ICLAFiles.match_claRef('a')
      expect(res).to equal(nil)
    end
    it "should return 'ab' for 'ab'" do
      res = ASF::ICLAFiles.match_claRef('ab')
      expect(res).to eq('ab')
    end
    it "should return 'abc.pdf' for 'abc'" do
      res = ASF::ICLAFiles.match_claRef('abc')
      expect(res).to eq('abc.pdf')
    end
    it "should return 'abcd' for 'abcd'" do
      res = ASF::ICLAFiles.match_claRef('abcd')
      expect(res).to eq('abcd')
    end
    it "should return 'abcde' for 'abcde'" do
      res = ASF::ICLAFiles.match_claRef('abcde')
      expect(res).to eq('abcde')
    end
  end

end
