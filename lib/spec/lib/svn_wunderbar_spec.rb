# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'
require 'whimsy/asf'
require 'wunderbar'

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
    exp = ["svn", "info", "https://svn.apache.org/repos/asf/attic/site/xdocs/projects/_template.xml", "--non-interactive"]
    expect(out['transcript'][1]).to eq(exp.inspect)
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
