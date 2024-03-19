#!/usr/bin/env ruby

=begin

Check state of asf-banned accounts.

An account that is asf-banned due to deceased/opted out should have:
- asf-banned = yes
- loginShell = /usr/bin/false
- neither of the following attributes exist: host sshPublicKey

=end

$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'whimsy/asf/mlist'
require 'wunderbar'

CHECKS = {
  'asf-banned' => 'yes',
  'loginShell' => '/usr/bin/false',
  'host' => nil,
  'sshPublicKey' => nil,
}

def singleton(attr)
  return attr.first if attr&.size == 1
  attr
end

# banned or false?
ATTRS=%w{uid cn asf-banned loginShell host sshPublicKey modifiersName modifyTimestamp createTimestamp}

if ENV['QUERY_STRING'].include? 'checkShell'
  CHECKSHELL = true
  FILTER = '(|(asf-banned=*)(loginShell=/usr/bin/false))'
else
  FILTER = '(asf-banned=*)'
  CHECKSHELL = false
end

_html do
  _style %{
    .error {background-color: yellow}
    table, th, td {border: 1px solid black}
    td {padding: 3px 6px}
    tr:hover td {background-color: azure}
    th {background-color: #a0ddf0}
  }

  _h1 'LDAP banned checks'

  _p %{
    This script compares the LDAP settings for asf-banned, loginShell and host.
    If asf-banned is set, it is expected to equal 'yes', and loginShell should be '/usr/bin/false'.
    Also host and sshPublicKey should be empty.
  }
  if CHECKSHELL
    _p %{
      Likewise, if loginShell is '/usr/bin/false', asf-banned should probably be 'yes', and the other two fields empty.
    }
  else
    _p do
      _a 'Append "?checkShell"', href: "#{ENV['SCRIPT_NAME']}?checkShell"
      _ ' to the URL to check against loginShell=/usr/bin/false'
    end
  end

  _table do
    _tr do
      _th 'UID'
      _th 'Name'
      _th 'asf-banned?'
      _th 'loginShell'
      _th 'Host'
      _th 'sshPublicKey count'
      _th 'Created'
      _th 'LastModified'
      _th 'ModifiedBy'
    end

    banned = ASF::Person.ldap_search(FILTER,ATTRS)
    banned.sort_by {|h| h['uid']}.each do |attrs|
      errs = {}
      CHECKS.each do |k,v|
        attr = attrs[k]
        if v.nil? # special handling
          errs[k] = 'error' unless attr.nil?
        else
          errs[k] = 'error' unless singleton(attr) == v
        end
      end
      if errs.size > 0 # Found an error
        _tr do
          _td singleton attrs['uid']
          _td singleton attrs['cn']
          _td singleton(attrs['asf-banned']), class: errs['asf-banned']
          _td singleton(attrs['loginShell']), class: errs['loginShell']
          _td attrs['host']&.join(','), class: errs['host']
          _td attrs['sshPublicKey']&.size, class: errs['sshPublicKey']
          _td singleton attrs['createTimestamp']
          _td singleton attrs['modifyTimestamp']
          _td singleton attrs['modifiersName']
        end
      end
    end
  end

end
