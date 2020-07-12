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
  fields = {fullname: 'Full Name', address: "Line 1\nLine2", availid: 'a-b-c', email: 'user@domain.invalid'}
  it "make_entry() should raise error" do
    expect { ASF::Member.make_entry(fields.reject{|k,v| k == :fullname}) }.to raise_error(ArgumentError, ':fullname is required')
    expect { ASF::Member.make_entry(fields.reject{|k,v| k == :address}) }.to raise_error(ArgumentError, ':address is required')
    expect { ASF::Member.make_entry(fields.reject{|k,v| k == :availid}) }.to raise_error(ArgumentError, ':availid is required')
    expect { ASF::Member.make_entry(fields.reject{|k,v| k == :email}) }.to raise_error(ArgumentError, ':email is required')
  end
  it "make_entry(fields) should create entry" do
    res = ASF::Member.make_entry(fields)
    expect(res).to eq("Full Name\n    Line 1\n    Line2\n    Email: user@domain.invalid\n Forms on File: ASF Membership Application\n Avail ID: a-b-c\n")
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
end

