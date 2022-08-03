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

describe ASF::Committee do
  before {
    Wunderbar.logger = nil # ensure we see warnings
  }
  describe "ASF::Committee::site" do
    it "should return string for 'httpd'" do
      res = ASF::Committee.find('HTTP Server').site
      expect(res).to match(%r{https?://httpd\.apache\.org/?})
    end

    it "should return nil for 'z-z-z'" do
      res = ASF::Committee.find('z-z-z').site
      expect(res.class).to eq(NilClass)
    end
  end

  describe "ASF::Committee::description" do
    it "should return string for 'httpd'" do
      res = ASF::Committee.find('HTTP Server').description
      expect(res).to match(%r{Apache Web Server})
    end
    it "should return nil for 'z-z-z'" do
      res = ASF::Committee.find('z-z-z').description
      expect(res.class).to eq(NilClass)
    end
  end

  describe "ASF::Committee.metadata" do
    it "should return hash for 'httpd'" do
      res = ASF::Committee.metadata('httpd')
      expect(res.class).to eq(Hash)
      expect(res[:site]).to match(%r{https?://httpd\.apache\.org/?})
    end

    it "should return nil for 'z-z-z'" do
      res = ASF::Committee.metadata('z-z-z')
      expect(res.class).to eq(NilClass)
    end

    it "should return hash for 'httpd Committee'" do
      cttee = ASF::Committee.find('HTTP Server')
      res = ASF::Committee.metadata(cttee)
      expect(res.class).to eq(Hash)
      expect(res[:site]).to match(%r{https?://httpd\.apache\.org/?})
    end

    it "should return hash for 'comdev'" do
      res = ASF::Committee.metadata('comdev')
      expect(res.class).to eq(Hash)
      expect(res[:site]).to match(%r{https?://community\.apache\.org/?})
    end
  end

  date_established = Date.parse('1970-01-01')
  established_value = '1970-01' # as per yaml

  describe "ASF::Committee.appendtlpmetadata" do
    board = ASF::SVN.find('board')
    file = File.join(board, 'committee-info.yaml')
    input = File.read(file)
    it "should fail for 'httpd'" do
      res = nil
      expect {
        res = ASF::Committee.appendtlpmetadata(input, 'httpd', 'description', date_established)
      }.to output("_WARN Entry for 'httpd' already exists under :tlps\n").to_stderr
      expect(res).to eql(input)
    end

    it "should fail for 'comdev'" do
      res = nil
      expect {
        res = ASF::Committee.appendtlpmetadata(input, 'comdev', 'description', date_established)
      }.to output("_WARN Entry for 'comdev' already exists under :cttees\n").to_stderr
      expect(res).to eql(input)
    end

    pmc = 'a-b-c'
    it "should succeed for '#{pmc}'" do
      res = nil
      desc = 'Description of A-B-C'
      expect { res = ASF::Committee.appendtlpmetadata(input, pmc, desc, date_established) }.to output("").to_stderr
      expect(res).not_to eq(input)
      tlps = YAML.safe_load(res, permitted_classes: [Symbol])[:tlps]
      abc = tlps[pmc]
      expect(abc.class).to eq(Hash)
      expect(abc[:site]).to match(%r{https?://#{pmc}\.apache\.org/?})
      expect(abc[:description]).to eq(desc)
      expect(abc[:established]).to eq(established_value)
    end

    it "resume should succeed for 'avalon' (no current diary)" do
      pmc = 'avalon'
      original = YAML.safe_load(input, permitted_classes: [Symbol])[:tlps][pmc]
      expect(original[:retired]).not_to be_nil
      expect(original[:diary]).to be_nil
      date_resumed = Time.now
      resumed_value = date_resumed.strftime('%Y-%m')
      res = nil
      expect { res = ASF::Committee.appendtlpmetadata(input, pmc, 'unused', date_resumed) }.to output("").to_stderr
      expect(res).not_to equal(input)
      tlps = YAML.safe_load(res, permitted_classes: [Symbol])[:tlps]
      updated = tlps[pmc]
      expect(updated.class).to eq(Hash)
      expect(updated[:site]).to eq(original[:site])
      expect(updated[:retired]).to be_nil # no longer retired
      expect(updated[:description]).to eq(original[:description])
      expect(updated[:established]).to eq(original[:established])
      diary = [
        {established: original[:established]},
        {retired: original[:retired]},
        {resumed: resumed_value}
      ]
      expect(updated[:diary]).to eq(diary)
    end

    it "resume should succeed for 'jakarta' (has diary)" do
      pmc = 'jakarta'
      original = YAML.safe_load(input, permitted_classes: [Symbol])[:tlps][pmc]
      expect(original[:retired]).not_to be_nil
      expect(original[:diary]).not_to be_nil
      date_resumed = Time.now
      resumed_value = date_resumed.strftime('%Y-%m')
      res = nil
      expect { res = ASF::Committee.appendtlpmetadata(input, pmc, 'unused', date_resumed) }.to output("").to_stderr
      expect(res).not_to equal(input)
      tlps = YAML.safe_load(res, permitted_classes: [Symbol])[:tlps]
      updated = tlps[pmc]
      expect(updated.class).to eq(Hash)
      expect(updated[:site]).to eq(original[:site])
      expect(updated[:retired]).to be_nil # no longer retired
      expect(updated[:description]).to eq(original[:description])
      expect(updated[:established]).to eq(original[:established])
      diary = [
        {retired: original[:retired]},
        {resumed: resumed_value}
      ]
      expect(updated[:diary]).to eq(diary)
    end
  end

  describe "ASF::ASF::Committee.record_termination" do
    cinfoy = File.join(ASF::SVN['board'], 'committee-info.yaml')
    yyyymm = '2020-10'
    data = File.read cinfoy
    yaml = YAML.safe_load(data, permitted_classes: [Symbol])
    it "should contain HTTPD, but not retired" do
      para = yaml[:tlps]['httpd']
      expect(para).not_to eql(nil)
      expect(para[:retired]).to eql(nil)
    end
    it "should add retired tag to HTTPD" do
      data = ASF::Committee.record_termination(data, 'HTTP Server', yyyymm)
      yaml = YAML.safe_load(data, permitted_classes: [Symbol])
      para = yaml[:tlps]['httpd']
      expect(para).not_to eql(nil)
      expect(para[:retired]).to eql(yyyymm)
      expect(para[:name]).to eql('HTTP Server')
    end
    yaml = YAML.safe_load(data, permitted_classes: [Symbol])
    name = 'XYZXYZ'
    pmc = ASF::Committee.to_canonical(name)
    it "should not contain XYZXYZ" do
      para = yaml[:tlps][pmc]
      expect(para).to eql(nil)
    end
    it "should now contain XYZXYZ" do
      data = ASF::Committee.record_termination(data, name, yyyymm)
      yaml = YAML.safe_load(data, permitted_classes: [Symbol])
      para = yaml[:tlps][pmc]
      expect(para).not_to eql(nil)
      expect(para[:retired]).to eql(yyyymm)
      expect(para[:name]).to eql(name)
    end
  end
end
