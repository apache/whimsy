# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'
require 'whimsy/asf'
require 'wunderbar'

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
    expect(out['transcript'][1]).to eq(exp.inspect)
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

  it "svn_('help', 'help', _, {args: ['--depth','empty'], dryrun: true}) should return the same as {depth: 'files'}" do
    rc1, out1 = _json do |_|
      ASF::SVN.svn_('help', 'help', _, {args: ['--depth','empty'], dryrun: true})
    end
    rc2, out2 = _json do |_|
      ASF::SVN.svn_('help', 'help', _, {depth: 'empty', dryrun: true})
    end
    expect(rc1).to eq(0)
    expect(rc2).to eq(0)
    expect(out1).to eq(out2)
  end

  it "svn_('help', 'help', _, {args: ['--message','text'], dryrun: true}) should return the same as {msg: 'text'}" do
    rc1, out1 = _json do |_|
      ASF::SVN.svn_('help', 'help', _, {args: ['--message','text'], dryrun: true})
    end
    rc2, out2 = _json do |_|
      ASF::SVN.svn_('help', 'help', _, {msg: 'text', dryrun: true})
    end
    expect(rc1).to eq(0)
    expect(rc2).to eq(0)
    expect(out1).to eq(out2)
  end



end

describe "ASF::SVN.update" do
  it "update('_template.xml') should return array" do
    repo = File.join(ASF::SVN.svnurl('attic-xdocs'),'_template.xml')

    rc, out = _json do |_|
      ASF::SVN.update(repo, "Dummy message", ENV_.new, _, {dryrun:true}) do |tmpdir, contents|
        contents+"test\n"
      end
    end

    expect(rc).to be(nil) # update does not return a value
    expect(out['transcript'].class).to equal(Array)
    # could look for "Checked out revision" and "Update to revision"
    expect(out['transcript'][-1]).to eql('+test') # 
  end
end
