# encoding: utf-8
# frozen_string_literal: true
require 'spec_helper'
require 'whimsy/asf'

describe ASF::Mail do
  
  describe "ASF::Mail.to_canonical" do
    it "should return address unaltered for invalid emails" do
      email = 'textwithnoATsign'
      expect(ASF::Mail.to_canonical(email)).to eq(email)
      email = 'textwithtrailing@'
      expect(ASF::Mail.to_canonical(email)).to eq(email)
      email = '@textwithleadingAT'
      expect(ASF::Mail.to_canonical(email)).to eq(email)
    end    
    it "should return address with downcased domain for valid emails" do
      expect(ASF::Mail.to_canonical('ABC@DEF')).to eq('ABC@def')
    end    
    it "should return address with downcased domain and canonicalised name for Google emails" do
      expect(ASF::Mail.to_canonical('A.B.C+123@GMail.com')).to eq('abc@gmail.com')
    end    
  end

end
