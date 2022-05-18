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

`which svnmucc`
svnmucc_missing = $?.exitstatus == 0 ? false : "svnmucc not found"

describe "ASF::SVN.svn_!" do
  it "svn_!('info') should return array with Name:" do
    repo = File.join(ASF::SVN.svnurl('attic-xdocs'),'_template.xml')

    rc, out = _json do |_|
      ASF::SVN.svn_!('info', repo, _)
    end

    expect(rc).to be(0)
    expect(out['transcript'].class).to equal(Array)
    expect(out['transcript'].include?('Name: _template.xml')).to be(true)
  end
  it "svn_!('info', 'no file') should fail with E200009" do
    repo = File.join(ASF::SVN.svnurl('attic-xdocs'),'___')

    rc, out = _json do |_|
      ASF::SVN.svn_!('info', repo, _)
    end

    expect(rc).to be(nil)
    expect(out['transcript'].class).to equal(Array)
    expect(out['transcript'].join("\n")).to match(/svn: E200009:/)
  end
end

describe "ASF::SVN.svn_" do
  it "svn_(nil,nil,nil) should raise error" do
    expect { ASF::SVN.svn_(nil,nil,nil) }.to raise_error(ArgumentError, 'command must not be nil')
  end
  it "svn_('st',nil,nil) should raise error" do
    expect { ASF::SVN.svn_('st',nil,nil) }.to raise_error(ArgumentError, 'path must not be nil')
  end
  it "svn_('st','',nil) should raise error" do
    expect { ASF::SVN.svn_('st','',nil) }.to raise_error(ArgumentError, 'wunderbar (_) must not be nil')
  end
  it "svn_('st','',_,{xyz: true}) should raise error" do
    expect { ASF::SVN.svn_('st','',true,{xyz: true}) }.to raise_error(ArgumentError, 'Following options not recognised: [:xyz]')
  end

  it "svn_('info') should return array with Name:" do
    repo = File.join(ASF::SVN.svnurl('attic-xdocs'),'_template.xml')

    rc, out = _json do |_|
      ASF::SVN.svn_('info', repo, _)
    end

    expect(rc).to be(0)
    expect(out['transcript'].class).to equal(Array)
    expect(out['transcript'].include?('Name: _template.xml')).to be(true)
  end
  it "svn_('info') should return array" do
    repo = File.join(ASF::SVN.svnurl('attic-xdocs'),'_template.xml')

    rc, out = _json do |_|
      ASF::SVN.svn_('info', repo, _, {dryrun: true})
    end

    expect(rc).to be(0)
    expect(out['transcript'].class).to equal(Array)
    exp = ["svn", "info", "--non-interactive", "--", "https://svn.apache.org/repos/asf/attic/site/xdocs/projects/_template.xml"]
    expect(out['transcript'][1]).to eq(exp.join(' '))
  end
  it "svn_('info', 'no file') should fail with E200009" do
    repo = File.join(ASF::SVN.svnurl('attic-xdocs'),'___')

    rc, out = _json do |_|
      ASF::SVN.svn_('info', repo, _)
    end

    expect(rc).to be(1)
    expect(out['transcript'].class).to equal(Array)
    expect(out['transcript'].join("\n")).to match(/svn: E200009:/)
  end

  it "auth: should override env: and user:/password:" do
    rc1, out1 = _json do |_|
      ASF::SVN.svn_('help', 'help', _, {auth: [['--username', 'a', '--password', 'b']], env: ENV_.new('c','d'), user: 'user', password: 'pass', verbose: true, dryrun: true})
    end
    expect(rc1).to eq(0)
    exp = [["svn", "help", "--non-interactive", "--", "help"], {}]
    act = out1['transcript'][1]
    expect(act).to eq(exp.inspect)
  end

   it "env: should include password" do
    rc, out = _json do |_|
      ASF::SVN.svn_('help', 'help', _, {env: ENV_.new('a','b'), verbose: true})
    end
    expect(rc).to eq(0)
    act = out['transcript'][1]
    if ASF::SVN.passwordStdinOK?
      exp = [["svn", "help", "--non-interactive", ["--username", "a", "--no-auth-cache"], ["--password-from-stdin"], "--", "help"], {:stdin=>"b"}]
    else
      exp = [["svn", "help", "--non-interactive", ["--username", "a", "--no-auth-cache"], ["--password", "b"], "--", "help"], {}]
    end
    expect(act).to eq(exp.inspect)
   end

   it "env: should include password and override user" do
    rc, out = _json do |_|
      ASF::SVN.svn_('help', 'help', _, {env: ENV_.new('a','b'), verbose: true, user: 'user', password: 'pass'})
    end
    expect(rc).to eq(0)
    act = out['transcript'][1]
    if ASF::SVN.passwordStdinOK?
      exp = [["svn", "help", "--non-interactive", ["--username", "a", "--no-auth-cache"], ["--password-from-stdin"], "--", "help"], {:stdin=>"b"}]
    else
      exp = [["svn", "help", "--non-interactive", ["--username", "a", "--no-auth-cache"], ["--password", "b"], "--", "help"], {}]
    end
    expect(act).to eq(exp.inspect)
   end

   it "user: alone should not appear" do
    rc, out = _json do |_|
      ASF::SVN.svn_('help', 'help', _, {verbose: true, user: 'user'})
    end
    expect(rc).to eq(0)
    act = out['transcript'][1]
    exp = [["svn", "help", "--non-interactive", "--", "help"], {}]
    expect(act).to eq(exp.inspect)
   end

   it "user: and password: should appear" do
    rc, out = _json do |_|
      ASF::SVN.svn_('help', 'help', _, {verbose: true, user: 'user', password: 'pass'})
    end
    expect(rc).to eq(0)
    act = out['transcript'][1]
    if ASF::SVN.passwordStdinOK?
      exp = [["svn", "help", "--non-interactive", ["--username", "user", "--no-auth-cache"], ["--password-from-stdin"], "--", "help"], {:stdin=>"pass"}]
    else
      exp = [["svn", "help", "--non-interactive", ["--username", "user", "--no-auth-cache"], ["--password", "pass"], "--", "help"], {}]
    end
    expect(act).to eq(exp.inspect)
   end

   # TODO fix these tests
   it "['help'] should not include Global options" do
    rc, out = _json do |_|
      ASF::SVN.svn_(['help'], 'help', _)
    end
    expect(rc).to eq(0)
    act = out['transcript'].join(' ')
    expect(act).to match(/Describe the usage of this program or its subcommands./)
    # expect(act).not_to match(/Global options/)
   end

  #  it "['help','-v'] should include Global options" do
  #   rc, out = _json do |_|
  #     ASF::SVN.svn_(['help','-v'], 'help', _)
  #   end
  #   expect(rc).to eq(0)
  #   act = out['transcript'].join(' ')
  #   expect(act).to match(/Describe the usage of this program or its subcommands./)
  #   expect(act).to match(/Global options/)
  #  end
end

describe "ASF::SVN.update" do
  it "update('_template.xml') should return array" do
    repo = File.join(ASF::SVN.svnurl('attic-xdocs'),'_template.xml')

    rc, out = _json do |_|
      ASF::SVN.update(repo, "Dummy message", ENV_.new, _, {dryrun:true}) do |tmpdir, contents|
        contents+"test\n"
      end
    end

    expect(rc).to be(0)
    expect(out['transcript'].class).to equal(Array)
    # could look for "Checked out revision" and "Update to revision"
    expect(out['transcript'][-1]).to eql('+test') #
  end

end

describe "ASF::SVN.svnmucc_", skip: svnmucc_missing do
  it "svnmucc_(nil,nil,nil,nil,nil) should fail" do
    expect { ASF::SVN.svnmucc_(nil,nil,nil,nil,nil) }.to raise_error(ArgumentError, "commands must be an array")
  end
  it "svnmucc_([],nil,nil,nil,nil) should fail" do
    expect { ASF::SVN.svnmucc_([],nil,nil,nil,nil) }.to raise_error(ArgumentError, "msg must not be nil")
  end
  it "svnmucc_([],'test',nil,nil,nil) should fail" do
    expect { ASF::SVN.svnmucc_([],'test',nil,nil,nil) }.to raise_error(ArgumentError, "env must not be nil")
  end
  it "svnmucc_([],'test',ENV_.new,nil,nil) should fail" do
    expect { ASF::SVN.svnmucc_([],ENV_.new,'test',nil,nil) }.to raise_error(ArgumentError, "_ must not be nil")
  end
  it "svnmucc_([[],'x',[]],'test',ENV_.new,'_',nil) should fail" do
    expect { ASF::SVN.svnmucc_([[],'x',[]],ENV_.new,'test','_',nil) }.to raise_error(ArgumentError, "command entries must be an array")
  end
  it "svnmucc_([['xyz']],'test',ENV_.new,_,nil) should fail" do
    rc, out = _json do |_|
      ASF::SVN.svnmucc_([['xyz']],'test',ENV_.new,_,nil)
    end
    puts out if rc.nil? # Try to debug Travis OSX failure
    expect(rc).to eq(1)
  end
  it "svnmucc_([['help']],'test',ENV_.new,_,nil) should produce help message with --message test" do
    rc, out = _json do |_|
      ASF::SVN.svnmucc_([['help']],'test',ENV_.new,_,nil)
    end
    expect(rc).to eq(0)
    expect(out).to be_kind_of(Hash)
    ts = out['transcript']
    expect(ts).to be_kind_of(Array)
    expect(ts[0]).to match(/--message test/)
    expect(ts[1]).to eq('usage: svnmucc ACTION...')
  end
  it "svnmucc_([['help']],'test',ENV_.new,_,'x',nil) should fail with invalid revision number" do
    rc, out = _json do |_|
      ASF::SVN.svnmucc_([['help']],'test',ENV_.new,_,'x')
    end
    expect(rc).to eq(1)
    expect(out).to be_kind_of(Hash)
    ts = out['transcript']
    expect(ts).to be_kind_of(Array)
    expect(ts[0]).to match(/--revision x/)
    expect(ts[1]).to eq('svnmucc: E205000: Invalid revision number \'x\'')
  end
  it "svnmucc_([['help']],'test',ENV_.new,_,'123',nil) should show revision in command" do
    rc, out = _json do |_|
      ASF::SVN.svnmucc_([['help']],'test',ENV_.new,_,'123')
    end
    expect(rc).to eq(0)
    expect(out).to be_kind_of(Hash)
    ts = out['transcript']
    expect(ts).to be_kind_of(Array)
    expect(ts[0]).to match(/--revision 123/)
  end
  it "svnmucc_([['help']],'test',ENV_.new,_,nil) should not show revision in command" do
    rc, out = _json do |_|
      ASF::SVN.svnmucc_([['help']],'test',ENV_.new,_,nil)
    end
    expect(rc).to eq(0)
    expect(out).to be_kind_of(Hash)
    ts = out['transcript']
    expect(ts).to be_kind_of(Array)
    expect(ts[0]).not_to match(/--revision/)
  end
  it "svnmucc_([['help']],'test',ENV_.new,_,nil,{tmpdir: tmpdir}) should have tmpdir in command" do
    tmpdir=Dir.mktmpdir
    path=File.join(tmpdir,'*')
    expect(Dir[path]).to eq([])
    rc, out = _json do |_|
      ASF::SVN.svnmucc_([['help']],'test',ENV_.new,_,nil,{tmpdir: tmpdir})
    end
    expect(rc).to eq(0)
    expect(out).to be_kind_of(Hash)
    ts = out['transcript']
    expect(ts).to be_kind_of(Array)
    expect(ts[0]).to match(%r{--extra-args #{tmpdir}})
    expect(Dir[path]).to eq([]) # no files remaining
  end
  it "svnmucc_([['help']],'test',ENV_.new,_,nil,{dryrun: true}) should echo params" do
    rc, out = _json do |_|
      ASF::SVN.svnmucc_([['help']],'test',ENV_.new,_,nil,{dryrun: true})
    end
    expect(rc).to eq(0)
    expect(out).to be_kind_of(Hash)
    ts = out['transcript']
    expect(ts).to be_kind_of(Array)
    expect(ts.size).to eq(2)
    expect(ts[0]).to match(%r{\$ echo svnmucc .*--message test})
    expect(ts[1]).to match(%r{^svnmucc .*--message test})
  end
  it "svnmucc_([['help']],'test',ENV_.new,_,nil,{verbose: true}) should echo params" do
    rc, out = _json do |_|
      ASF::SVN.svnmucc_([['help']],'test',ENV_.new,_,nil,{verbose: true})
    end
    expect(rc).to eq(0)
    expect(out).to be_kind_of(Hash)
    ts = out['transcript']
    expect(ts).to be_kind_of(Array)
    expect(ts[0]).to match(%r{\$ echo})
    # either --password pass or --password-from-stdin {:stdin=>\"pass\"}
    # This depends on the order in which the command line is built up
    expect(ts[1]).to match(%r{^svnmucc .*--message test .*--username user --password.+pass})
    expect(ts[4]).to eq('usage: svnmucc ACTION...') # output of svnmucc help
  end
  it "svnmucc_([['help']],'test',ENV_.new,_,nil,{root: root}) should include --root-url" do
    root = ASF::SVN.svnurl!(SAMPLE_SVN_NAME)
    rc, out = _json do |_|
      ASF::SVN.svnmucc_([['help']],'test',ENV_.new,_,nil,{root: root})
    end
    expect(rc).to eq(0)
    expect(out).to be_kind_of(Hash)
    ts = out['transcript']
    expect(ts).to be_kind_of(Array)
    expect(ts[0]).to match(%r{^\$ svnmucc .*--message test .*--root-url #{root}})
    expect(ts[1]).to eq('usage: svnmucc ACTION...') # output of svnmucc help
  end
end
