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
require 'whimsy/asf/yaml'

describe YamlFile do
  tmpdir = Dir.mktmpdir
  tmpname = File.join(tmpdir, 'yaml_spec1.yaml')
  describe "YamlFile.read" do
    it "should fail ENOENT" do
      expect do
        YamlFile.read(tmpname)
      end.to raise_error(Errno::ENOENT)
    end
  end
  describe "YamlFile.update_section" do
    tmpdir = Dir.mktmpdir
    tmpname = File.join(tmpdir, 'yaml_spec1.yaml')
    it "should fail ENOENT" do
      expect do
        YamlFile.update_section(tmpname, nil) {|yaml| yaml}
      end.to raise_error(Errno::ENOENT)
    end
    testfile = fixture_path('sample.yaml')
    workfile = File.join(tmpdir, 'yaml_spec2.yaml')
    FileUtils.cp testfile, workfile
    # Check copied file is OK
    it "read should return 3 entries" do
      yaml = YamlFile.read(workfile)
      expect(yaml.size).to equal(3)
    end
    it "should fail with missing section and not update file" do
      mtime = File.mtime workfile
      expect do
        YamlFile.update_section(workfile, 'none') {|yaml| yaml}
      end.to raise_error(ArgumentError)
      expect(File.mtime(workfile)).to eql(mtime)
    end
    it "should find 2 entries and touch file" do
      mtime = File.mtime workfile
      YamlFile.update_section(workfile, :key1) do |yaml|
        expect(yaml.size).to eql(2)
        yaml # return it unchanged
      end
      expect(File.mtime(workfile)).to be > mtime
    end
    # check it is still OK after dummy update
    it "read should return 3 entries" do
      yaml = YamlFile.read(workfile)
      expect(yaml.size).to equal(3)
    end
    it "should be unchanged" do
      expect(File.read(testfile)).to eql(File.read(workfile))
    end
    it "should not touch file if nil returned" do
      mtime = File.mtime workfile
      YamlFile.update_section(workfile, :key1) do |yaml|
        expect(yaml.size).to eql(2)
        nil # return it unchanged
      end
      expect(File.mtime(workfile)).to eql(mtime)
    end
  end
  describe "YamlFile.update" do
    tmpname = File.join(tmpdir, 'yaml_spec3.yaml')
    it "should create empty file" do
      YamlFile.update(tmpname) do |yaml|
        expect(yaml.class).to equal(Hash)
        expect(yaml.size).to equal(0)
        yaml['test'] = {a: 'b'}
        expect(yaml.size).to equal(1)
        yaml
      end
    end
    it "read should return single entry" do
      yaml = YamlFile.read(tmpname)
      expect(yaml.size).to equal(1)
    end
    it "read not change the file time-stamp" do
      mtime1 = File.mtime(tmpname)
      YamlFile.update(tmpname) do |yaml|
        expect(yaml.class).to equal(Hash)
        expect(yaml.size).to equal(1)
        yaml['test2'] = {a: 'b'}
        expect(yaml.size).to equal(2)
        nil
      end
      mtime2 = File.mtime(tmpname)
      expect(mtime2).to eq(mtime1)
    end
  end
end
