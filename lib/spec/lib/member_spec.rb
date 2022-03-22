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

set_svn('foundation') # need private file

describe ASF::Member do
  it  "find_text_by_id('notinavail') should return nil" do
    res = ASF::Member.find_text_by_id('notinavail')
    expect(res).to eq(nil)
  end
  it  "find_text_by_id('banana') should return entry" do
    res = ASF::Member.find_text_by_id('banana')
    expect(res).to match(%r{^Barry N Anaheim.+Avail ID: banana}m)
  end
  it  "find_text_by_id('cherry') should return entry (emeritus)" do
    res = ASF::Member.find_text_by_id('cherry')
    expect(res).to match(%r{^Charlie .+^ Avail ID: cherry}m)
  end
  it  "find_text_by_id('elder') should return entry (deceased)" do
    res = ASF::Member.find_text_by_id('elder')
    expect(res).to match(%r{^El Dorado.+^ Avail ID: elder}m)
  end
  it  "find_by_email('dorado@gmail.com.invalid') should return ASF::Person" do
    res = ASF::Member.find_by_email('dorado@gmail.com.invalid')
    expect(res).to be_kind_of(ASF::Person)
  end
  it  "find_by_email('invalid@invalid') should return nil" do
    res = ASF::Member.find_by_email('invalid@invalid')
    expect(res).to eq(nil)
  end
  fields = {fullname: 'Full Name', address: "Line 1\nLine2", availid: 'a-b-c', email: 'user@domain.invalid'}
  it "make_entry() should raise error" do
    expect { ASF::Member.make_entry(fields.reject{|k,v| k == :fullname}) }.to raise_error(ArgumentError, ':fullname is required')
    expect { ASF::Member.make_entry(fields.reject{|k,v| k == :availid}) }.to raise_error(ArgumentError, ':availid is required')
  end
  it "make_entry(fields) should create entry" do
    res = ASF::Member.make_entry(fields)
    expect(res).to eq(
        <<~MEMAPP
            Full Name
                Line 1
                Line2
                <Country>
                Email: user@domain.invalid
                  Tel: <phone number>
             Forms on File: ASF Membership Application
             Avail ID: a-b-c
        MEMAPP
    )
  end
  it "make_entry({country:}}) should create entry with country" do
    res = ASF::Member.make_entry(fields.merge({country: 'UN'}))
    expect(res).to match(%r{^    UN$})
  end
  it "make_entry({tele:}}) should create entry with Tel:" do
    res = ASF::Member.make_entry(fields.merge({tele: '123-456'}))
    expect(res).to match(%r{^      Tel: 123-456$})
  end
  it "make_entry({fax:}}) should create entry with Fax:" do
    res = ASF::Member.make_entry(fields.merge({fax: '123-456'}))
    expect(res).to match(%r{^      Fax: 123-456$})
  end
  it "status should return hash" do
    res = ASF::Member.status
    expect(res).to be_kind_of(Hash)
    expect(res.size).to eq(3)
    expect(res.keys.sort).to eq(["cherry", "damson", "elder"])
  end
  it "emeritus should return hash" do
    res = ASF::Member.emeritus
    expect(res).to be_kind_of(Array)
    expect(res.size).to eq(2)
    expect(res.sort).to eq(["cherry", "damson"])
  end
  it "find('cherry') should return true" do
    res = ASF::Member.find('cherry')
    expect(res).to eq(true)
  end
  it "find('notinavail') should return false" do
    res = ASF::Member.find('notinavail')
    expect(res).to eq(false)
  end
  it "text should return File.read('members.txt')" do
    exp = File.read(File.join(ASF::SVN['foundation'],'members.txt'))
    act = ASF::Member.text
    expect(act).to eq(exp)
  end
  it "get_name(find_text_by_id('cherry')) should return Charlie Ryman" do
    txt = ASF::Member.find_text_by_id('cherry')
    res = ASF::Member.get_name(txt)
    expect(res).to eq('Charlie Ryman')
  end
end

