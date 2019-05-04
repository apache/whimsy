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
    it "should return address with downcased domain and canonicalised name for GMail emails" do
      expect(ASF::Mail.to_canonical('A.B.C+123@GMail.com')).to eq('abc@gmail.com')
    end    
    it "should return address with downcased domain and canonicalised name for Googlemail emails" do
      expect(ASF::Mail.to_canonical('A.B.C+123@Googlemail.com')).to eq('abc@gmail.com')
    end    
  end

  describe '.cansub(member, pmc_chair, ldap_pmcs)' do
    lists = ASF::Mail.cansub(false, false, nil)
    it 'should return public lists only' do
      whitelist = ['infra-users', 'jobs', 'site-dev', 'committers-cvs', 'site-cvs', 'concom', 'party']
      board = ['board', 'board-commits', 'board-chat']
      expect(lists.length).to be >= 1000
      expect(lists).not_to include('private')
      expect(lists).not_to include('security')
      expect(lists).to include(*whitelist)
      expect(lists).not_to include(*board)
    end
    it 'should return the same lists' do
      mylists = ASF::Mail.cansub(false, false, []) - lists
      expect(mylists.length).to be(0)
    end
    it 'should return private PMC lists' do
      mylists = ASF::Mail.cansub(false, false, ['ant','whimsical']) - lists
      expect(mylists.length).to be(2)
      expect(mylists).to include('ant-private','whimsical-private')
    end
    it 'should not return non-existent lists' do
      mylists = ASF::Mail.cansub(false, false, ['xxxant','xxxwhimsical']) - lists
      expect(mylists.length).to be(0)
    end
    it 'should return private PPMC lists' do
      podnames = ASF::Podling.current.map(&:name)
      mylists = ASF::Mail.cansub(false, false, podnames) - lists
      expect(mylists.length).to be_between(podnames.length-2, podnames.length).inclusive # mailing list may not be set up yet
    end
  end
end
