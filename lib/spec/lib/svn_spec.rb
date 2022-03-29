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
require 'wunderbar'

SAMPLE_MISSING_NAME = '__templates' # no such entry
SAMPLE_ALIAS = 'Bills' # depth: 'skip'

describe ASF::SVN do

  # repo_entry should only include repos that have local workspaces

  describe "ASF::SVN.repo_entry" do
    it "should return Hash for #{SAMPLE_SVN_NAME}" do
      res = ASF::SVN.repo_entry(SAMPLE_SVN_NAME)
      expect(res.class).to equal(Hash)
    end

    it "should return nil for #{SAMPLE_ALIAS}" do
      res = ASF::SVN.repo_entry(SAMPLE_ALIAS)
      expect(res.class).to equal(NilClass)
    end

    it "should return nil for #{SAMPLE_MISSING_NAME}" do
      res = ASF::SVN.repo_entry(SAMPLE_MISSING_NAME)
      expect(res.class).to equal(NilClass)
    end

  end

  describe "ASF::SVN.repo_entry!" do
    it "should return string for #{SAMPLE_SVN_NAME}" do
      res = ASF::SVN.repo_entry!(SAMPLE_SVN_NAME)
      expect(res.class).to equal(Hash)
    end

    it "should fail for #{SAMPLE_MISSING_NAME}" do
      expect{
        ASF::SVN.repo_entry!(SAMPLE_MISSING_NAME)
      }.to raise_error(Exception)
    end

  end

  # svnurl should include aliases

  describe "ASF::SVN.svnurl" do
    it "should return URL for #{SAMPLE_SVN_NAME}" do
      res = ASF::SVN.svnurl(SAMPLE_SVN_NAME)
      expect(res.class).to equal(String)
      expect(res).to match(SAMPLE_SVN_URL_RE)
    end

    it "should return URL for #{SAMPLE_ALIAS}" do
      res = ASF::SVN.svnurl(SAMPLE_ALIAS)
      expect(res.class).to equal(String)
      expect(res).to match(%r{https://.+/Bills})
    end

    it "should return nil for #{SAMPLE_MISSING_NAME}" do
      res = ASF::SVN.svnurl(SAMPLE_MISSING_NAME)
      expect(res.class).to equal(NilClass)
    end

  end

  describe "ASF::SVN.svnurl!" do
    it "should return URL for #{SAMPLE_SVN_NAME}" do
      res = ASF::SVN.svnurl!(SAMPLE_SVN_NAME)
      expect(res.class).to equal(String)
      expect(res).to match(SAMPLE_SVN_URL_RE)
    end

    it "should fail for #{SAMPLE_MISSING_NAME}" do
      expect {
        ASF::SVN.svnurl!(SAMPLE_MISSING_NAME)
      }.to raise_error(Exception)
    end

  end

  # repo_entries should exclude aliases

  describe "ASF::SVN.repo_entries" do
    it "should return hash with #{SAMPLE_SVN_NAME} but not #{SAMPLE_ALIAS}" do
      res = ASF::SVN.repo_entries
      expect(res.class).to equal(Hash)
      expect(res[SAMPLE_SVN_NAME].class).to equal(Hash)
      expect(res[SAMPLE_ALIAS]).to equal(nil)
    end

  end

  # find returns local workspace so excludes aliases

  describe "ASF::SVN.find" do
    it "should return string for #{SAMPLE_SVN_NAME}" do
      res = ASF::SVN.find(SAMPLE_SVN_NAME)
      expect(res.class).to equal(String)
    end

    it "should return nil for #{SAMPLE_ALIAS}" do
      res = ASF::SVN.find(SAMPLE_ALIAS)
      expect(res.class).to equal(NilClass)
    end

    it "should return nil for #{SAMPLE_MISSING_NAME}" do
      res = ASF::SVN.find(SAMPLE_MISSING_NAME)
      expect(res.class).to equal(NilClass)
    end

  end

  describe "ASF:SVN.private_public" do
    it "should return an array of size 2" do
      res = ASF::SVN.private_public
      expect(res.size()).to eq(2)
      expect(res[0].size).to eq(15) # will need to be adjusted from time to time
      expect(res[1].size).to eq(6) # ditto.
    end
  end

  describe "ASF:SVN.getInfo(repo)" do
#    it "getInfo(public workspace) should return a string at least 30 chars long starting with 'Path: '" do
#      pub = ASF::SVN.private_public()[1]
#      repo = ASF::SVN[pub[1]] # select a public repo
#      out, err = ASF::SVN.getInfo(repo)
#      expect(err).to eq(nil)
#      expect(out.size).to be > 30
#      expect(out).to start_with("Path: ")
#    end

#    it "getInfo(private workspace) should return a string at least 30 chars long starting with 'Path: '" do
#      prv = ASF::SVN.private_public()[0]
#      repo = ASF::SVN[prv[1]] # select a private repo
#      out, err = ASF::SVN.getInfo(repo)
#      expect(err).to eq(nil)
#      expect(out.size).to be > 30
#      expect(out).to start_with("Path: ")
#    end

    it "getInfo(public url) should return a string at least 30 chars long starting with 'Path: '" do
      pub = ASF::SVN.private_public()[1]
      repo = ASF::SVN.svnurl(pub[1]) # select a public repo url
      expect(repo).to start_with("https://")
      out, err = ASF::SVN.getInfo(repo)
      expect(err).to eq(nil)
      expect(out.size).to be > 30
      expect(out).to start_with("Path: ")
    end

    it "getInfo(nil) should fail" do
      expect { ASF::SVN.getInfo(nil) }.to raise_error(ArgumentError, 'path must not be nil')
    end

# How to ensure local SVN cached auth is not used?
#    it "getInfo(private url) should return a string at least 30 chars long starting with 'Path: '" do
#      prv = ASF::SVN.private_public()[0]
#      repo = ASF::SVN.svnurl(prv[1]) # select a private repo
#      expect(repo).to start_with("https://")
#      out, err = ASF::SVN.getInfo(repo)
#      expect(err).to eq(nil)
#      expect(out.size).to be > 30
#      expect(out).to start_with("Path: ")
#    end

  end

  describe "ASF:SVN.getInfoItem" do
#    it "getInfoItem(public checkout,'url') should return the URL" do
#      pub = ASF::SVN.private_public()[1]
#      repo = ASF::SVN[pub[1]] # select a public repo
#      out, err = ASF::SVN.getInfoItem(repo,'url')
#      expect(err).to eq(nil)
#      expect(out).to eq(ASF::SVN.svnurl(pub[1]))
#    end

    it "getInfoItem(public url,'url') should return the URL" do
      pub = ASF::SVN.private_public()[1]
      repo = ASF::SVN.svnurl(pub[1]) # select a public repo URL
      out, err = ASF::SVN.getInfoItem(repo,'url')
      expect(err).to eq(nil)
      expect(out).to eq(ASF::SVN.svnurl(pub[1]))
    end
  end

  describe "ASF:SVN.list" do
#    it "list(public checkout,'url') should return a list" do
#      pub = ASF::SVN.private_public()[1]
#      repo = ASF::SVN[pub[1]] # select a public repo
#      out, err = ASF::SVN.list(repo)
#      expect(err).to eq(nil)
#      expect(out.size).to be > 10 # need a better test
#    end

    it "list(public url,'url') should return a list" do
      pub = ASF::SVN.private_public()[1]
      repo = ASF::SVN.svnurl(pub[1]) # select a public repo URL
      out, err = ASF::SVN.list(repo)
      expect(err).to eq(nil)
      expect(out.size).to be > 10 # need a better test
    end
  end

  describe "ASF:SVN.get" do
#    it "get(public checkout,'_template.xml') should return the revision and contents" do
#      repo = File.join(ASF::SVN['attic-xdocs'],'_template.xml')
#      revision, content = ASF::SVN.get(repo)
#      expect(revision).to match(/\d+/)
#      expect(content.size).to be > 1000 # need a better test
#    end

    it "get(public url,'_template.xml') should return the revision and contents" do
      repo = File.join(ASF::SVN.svnurl('attic-xdocs'),'_template.xml')
      revision, content = ASF::SVN.get(repo)
      expect(revision).to match(/\d+/)
      expect(content.size).to be > 1000 # need a better test
    end
    it "get(public url,'_____') should return 0 and nil" do
      repo = File.join(ASF::SVN.svnurl('attic-xdocs'),'_____')
      revision, content = ASF::SVN.get(repo)
      expect(revision).to eq('0')
      expect(content).to eq(nil)
    end
  end

  describe "ASF::SVN.passwordStdinOK?" do
    it "passwordStdinOK? should return true or false" do
      res = ASF::SVN.passwordStdinOK?
      expect(res).to be(true).or be(false)
      # show what we are working with
      ver = %x(svn --version --quiet).chomp
      puts "\n>> version = '#{ver}' passwordStdinOK = #{res}"
    end
  end

  describe "ASF::SVN.svn" do
    it "svn(nil,nil) should raise error" do
      expect { ASF::SVN.svn(nil,nil) }.to raise_error(ArgumentError, 'command must not be nil')
    end
    it "svn('st',nil) should raise error" do
      expect { ASF::SVN.svn('st',nil) }.to raise_error(ArgumentError, 'path must not be nil')
    end
    it "svn('st','',{xyz: true}) should raise error" do
      expect { ASF::SVN.svn('st','',{xyz: true}) }.to raise_error(ArgumentError, 'Following options not recognised: [:xyz]')
    end

    it "svn('info', path) should return 'Name: path'" do
      repo = File.join(ASF::SVN.svnurl('attic-xdocs'),'_template.xml')
      out, _err = ASF::SVN.svn('info',repo)
      expect(out).to match(/^Name: _template.xml$/)
    end
    it "svn('info', [path]) should return 'Name: path'" do
      repo = File.join(ASF::SVN.svnurl('attic-xdocs'),'_template.xml')
      out, _err = ASF::SVN.svn('info',[repo])
      expect(out).to match(/^Name: _template.xml$/)
    end
    it "svn('info', [path1, path2], {item: kind'}) should return 'file ...'" do
      path1 = File.join(ASF::SVN.svnurl('attic-xdocs'),'_template.xml')
      path2 = File.join(ASF::SVN.svnurl('attic-xdocs'),'jakarta.xml')
      out, _err = ASF::SVN.svn('info',[path1, path2], {item: 'kind'})
      expect(out).to match(/^file +https:/)
    end

    it "svn() should honour :chdir option" do
      pods = ASF::SVN['incubator-podlings'] # arbitrary, but must be set up in Rakefile and spec_helper
      if pods
        out, err = ASF::SVN.svn('info', '.', {chdir: pods})
        expect(err).to eq(nil)
        expect(out).to match(/^URL: /)
      end
    end

    # TODO fix these tests
    it "svn(['help'], 'help') should return some help" do
      out, _err = ASF::SVN.svn(['help'],'help')
      expect(out).to match(/Describe the usage of this program or its subcommands/)
    end
    # it "svn(['help', '-v'], 'help') should return Global help" do
    #   out, err = ASF::SVN.svn(['help', '-v'],'help')
    #   expect(out).to match(/Global options/)
    # end
    # it "svn(['help', '--verbose'], 'help') should return Global help" do
    #   out, err = ASF::SVN.svn(['help', '--verbose'],'help')
    #   expect(out).to match(/Global options/)
    # end
  end

  describe "ASF::SVN._svn_build_cmd" do
    it "_svn_build_cmd('help', 'path', {}) should include path" do
      cmd, stdin = ASF::SVN._svn_build_cmd('help', 'path', {})
      expect(stdin).to eq(nil)
      expect(cmd).to eq(["svn", "help", "--non-interactive", "--", "path"])
    end

    it "_svn_build_cmd('help', 'path', {user: 'whimsy'}) should not include username" do
      cmd, stdin = ASF::SVN._svn_build_cmd('help', 'path', {user: 'whimsy'})
      expect(stdin).to eq(nil)
      expect(cmd).to eq(["svn", "help", "--non-interactive", "--", "path"])
    end

    it "_svn_build_cmd('help', 'path', {user: 'whimsy', password: 'pass}) should include username" do
      cmd, stdin = ASF::SVN._svn_build_cmd('help', 'path', {user: 'whimsy', password: 'pass'})
      exp = ["svn", "help", "--non-interactive", ["--username", "whimsy", "--no-auth-cache"], "--", "path"]
      if ASF::SVN.passwordStdinOK?
        expect(stdin).to eq('pass')
        expect(cmd-exp).to eq([["--password-from-stdin"]])
      else
        expect(stdin).to eq(nil)
        expect(cmd-exp).to eq([["--password", "pass"]])
      end
    end

    it "_svn_build_cmd('help', 'path', {user: 'whimsysvn'}) should include username" do
      cmd, stdin = ASF::SVN._svn_build_cmd('help', 'path', {user: 'whimsysvn'})
      expect(stdin).to eq(nil)
      expect(cmd).to eq(["svn", "help", "--non-interactive", ["--username", "whimsysvn", "--no-auth-cache"], "--", "path"])
    end

    it "_svn_build_cmd('help', 'path', {user: 'whimsysvn', dryrun: false}) should include username" do
      cmd, stdin = ASF::SVN._svn_build_cmd('help', 'path', {user: 'whimsysvn', dryrun: false})
      expect(stdin).to eq(nil)
      expect(cmd).to eq(["svn", "help", "--non-interactive", ["--username", "whimsysvn", "--no-auth-cache"], "--", "path"])
    end
    it "_svn_build_cmd('help', 'path', {user: 'whimsysvn', dryrun: true}) should not include username" do
      cmd, stdin = ASF::SVN._svn_build_cmd('help', 'path', {user: 'whimsysvn', dryrun: true})
      expect(stdin).to eq(nil)
      expect(cmd).to eq(["svn", "help", "--non-interactive", "--", "path"])
    end

    it "_svn_build_cmd('help', 'path', {_error: true})  should raise error" do
      expect { ASF::SVN._svn_build_cmd('help', 'path', {_error: true}) }.to raise_error(ArgumentError, "Following options not recognised: [:_error]")
    end

    it "_svn_build_cmd('help', 'path', {quiet: true}) should include --quiet" do
      cmd, stdin = ASF::SVN._svn_build_cmd('help', 'path', {quiet: true})
      expect(stdin).to eq(nil)
      expect(cmd).to eq(["svn", "help", "--non-interactive", "--quiet", "--", "path"])
    end

    it "_svn_build_cmd('help', 'path', {item: 'url'}) should include --show-item url" do
      cmd, stdin = ASF::SVN._svn_build_cmd('help', 'path', {item: 'url'})
      expect(stdin).to eq(nil)
      expect(cmd).to eq(["svn", "help", "--non-interactive", "--show-item", 'url', "--", "path"])
    end

    it "_svn_build_cmd('help', 'path', {revision: '123'}) should include --revision 123" do
      cmd, stdin = ASF::SVN._svn_build_cmd('help', 'path', {revision: '123'})
      expect(stdin).to eq(nil)
      expect(cmd).to eq(["svn", "help", "--non-interactive", "--revision", '123', "--", "path"])
    end

    it "_svn_build_cmd(true, 'path') should fail with ArgumentError" do
      expect {ASF::SVN._svn_build_cmd(true, 'path', {}) }.to raise_error(ArgumentError, 'command must be a String or an Array of Strings')
    end

    it "_svn_build_cmd(['list', true], 'path') should fail with ArgumentError" do
      expect {ASF::SVN._svn_build_cmd([true], 'path', {}) }.to raise_error(ArgumentError, 'command true must be a String')
    end

    it "_svn_build_cmd([true], 'path') should fail with ArgumentError" do
      expect {ASF::SVN._svn_build_cmd([true], 'path', {}) }.to raise_error(ArgumentError, 'command true must be a String')
    end

    it "_svn_build_cmd(['help', 'xyz'], 'path') should report error" do
      expect {
         # seems to be necessary to reset logger otherwise output is lost. However it's only necessary in conjunction with
         # other tests such as committee_spec.rb (q.v.)
        Wunderbar.logger = nil
        ASF::SVN._svn_build_cmd(['help','xyz'], 'path', {})
      }.to output("_ERROR Invalid option \"xyz\"\n").to_stderr
    end

  end

  describe "ASF::SVN.svnpath!" do
    it "svnpath!('board', 'committee-info.txt') should be https://svn.apache.org/repos/private/committers/board/committee-info.txt" do
      exp = 'https://svn.apache.org/repos/private/committers/board/committee-info.txt'
      act = ASF::SVN.svnpath!('board', 'committee-info.txt')
      expect(act).to eq(exp)
      act = ASF::SVN.svnpath!('board', '/committee-info.txt')
      expect(act).to eq(exp)
      act = ASF::SVN.svnpath!('board', '//committee-info.txt')
      expect(act).to eq(exp)
    end
  end

  describe "ASF::SVN.getlisting" do
    set_svnroot # need local test data here
    it "getlisting('emeritus') returns array of 1" do
      _tag, list = ASF::SVN.getlisting('emeritus')
      expect(list).to eq(['emeritus1.txt'])
    end
    it "getlisting('emeritus-requests-received') returns array of 1" do
      _tag, list = ASF::SVN.getlisting('emeritus-requests-received')
      expect(list).to eq(['emeritus3.txt'])
    end
    it "getlisting('emeritus-requests-received,nil,true,true') returns array of [epoch,name]" do
      _tag, list = ASF::SVN.getlisting('emeritus-requests-received',nil,true,true)
      expect(list).to eq([['1594814364','emeritus3.txt']])
    end
  end

  end
