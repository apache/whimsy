require 'spec_helper'
require 'whimsy/asf'

describe ASF::Person do
  it  "ldap_parse_cn_DRAFT('', false) should return [nil, []]" do
    res = ASF::Person.ldap_parse_cn_DRAFT('', false)
    expect(res).to eq([nil, []])
  end
  it  "ldap_parse_cn_DRAFT('', true) should return [nil, []]" do
    res = ASF::Person.ldap_parse_cn_DRAFT('', true)
    expect(res).to eq([nil, []])
  end
  # If there is only one name, it must be the surname
  it  "ldap_parse_cn_DRAFT('one', false) should return ['one', []]" do
    res = ASF::Person.ldap_parse_cn_DRAFT('one', false)
    expect(res).to eq(['one', []])
  end
  it  "ldap_parse_cn_DRAFT('one', true) should return ['one', []]" do
    res = ASF::Person.ldap_parse_cn_DRAFT('one', true)
    expect(res).to eq(['one', []])
  end
  it  "ldap_parse_cn_DRAFT('one two', false) should return ['two', ['one']]" do
    res = ASF::Person.ldap_parse_cn_DRAFT('one two', false)
    expect(res).to eq(['two', ['one']])
  end
  it  "ldap_parse_cn_DRAFT('one two', true) should return ['one', ['two']]" do
    res = ASF::Person.ldap_parse_cn_DRAFT('one two', true)
    expect(res).to eq(['one', ['two']])
  end
  it  "ldap_parse_cn_DRAFT('one two three', false) should return ['three', ['one', 'two']]" do
    res = ASF::Person.ldap_parse_cn_DRAFT('one two three', false)
    expect(res).to eq(['three', ['one', 'two']])
  end
  it  "ldap_parse_cn_DRAFT('one two three', tru) should return ['one', ['two', 'three']]" do
    res = ASF::Person.ldap_parse_cn_DRAFT('one two three', true)
    expect(res).to eq(['one', ['two', 'three']])
  end
end