# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'
require 'whimsy/asf'

set_root # need access to listing file

set_svn 'iclas' # only works with test data as real entry names should not be published
# Test data:
# ab/        abc.pdf    abcd/      abcd.pdf   abcde/

describe ASF::ICLAFiles do
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