# frozen_string_literal: true

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
    it "should fail with missing section" do
      expect do
        YamlFile.update_section(workfile, 'none') {|yaml| yaml}
      end.to raise_error(ArgumentError)
    end
    it "should find 2 entries" do
      YamlFile.update_section(workfile, :key1) do |yaml|
        expect(yaml.size).to eql(2)
        yaml # return it unchanged
      end
    end
    # check it is still OK after dummy update
    it "read should return 3 entries" do
      yaml = YamlFile.read(workfile)
      expect(yaml.size).to equal(3)
    end
    it "should be unchanged" do
      expect(File.read(testfile)).to eql(File.read(workfile))
    end
  end
  describe "YamlFile.update" do
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
  end
end
