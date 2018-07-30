#!/usr/bin/env ruby

=begin

Check LDAP names: cn, sn, givenName

Both givenName and sn should match part of cn

=end

$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'whimsy/asf'
require 'wunderbar/script'
require 'ruby2js/filter/functions'

_html do
  _style %{
    table {border-collapse: collapse}
    table, th, td {border: 1px solid black}
    td {padding: 3px 6px}
    tr:hover td {background-color: #FF8}
    th {background-color: #a0ddf0}
  }

 if @updates
  
  ################################################################## 
  #                         Apply Updates                          #
  ################################################################## 
  
  _h2_ 'Applying updates'
  updates = JSON.parse(@updates)
  
  # update LDAP
  unless updates.empty?
    unless ASF::Service.find('asf-secretary').members.include? ASF::Person.new($USER)
      print "Status: 401 Unauthorized\r\n"
      print "WWW-Authenticate: Basic realm=\"Secretary\"\r\n\r\n"
      exit
    end
    _pre 'ldapmodify', class: '_stdin'
    begin
      ASF::LDAP.bind($USER, $PASSWORD) do
        updates.each do |id, names|
          person = ASF::Person.new(id)
          _pre person.dn, class: '_stdout'
          _pre names.inspect, class: '_stdout'
          names.each do |k,v|
            begin
              person.modify k,v
            rescue => e
              _pre "Failed: #{e}", class: '_stdout'
            end
          end
        end
      end
      _pre 'Completed', class: '_stdout'
    rescue => e
      _pre updates.inspect, class: '_stdout'
      _pre "Failed: #{e}", class: '_stdout'
    end
  end
 else
  _h1 'LDAP people name checks'

  _p do
    _ 'LDAP sn and givenName must match part of cn'
    _br
    _ 'The table below show the differences, if any.'
    _br
    _ 'The Modify? columns show suggested fixes. If the name is non-italic then the suggestion is likely correct; italicised suggestions may be wrong/unnecessary.'
    _br
    _ 'The suggested name is considered correct if:'
    _ul do
      _li 'The existing field value matches the uid or the cn'
      _li 'The existing field is missing'
    end
  end

  _h2_ 'Instructions:'

  _ul do
    _li 'Double click a Modify? column to copy the contents one column to its left (cannot copy ???).'
    _li 'When done, click "Commit Changes" (at the bottom of the page).'
  end

  skipSN = ARGV.shift == 'skipSN' # skip entries with only bad SN

  # prefetch LDAP data
  people = ASF::Person.preload(%w(uid cn sn givenName loginShell))
  matches = 0
  badGiven = 0
  badSN = 0

  # prefetch ICLA data
  ASF::ICLA.preload

  _table do
    # Must agree with columnNames below
    _tr do
      _th 'uid'
      _th "ICLA file"
      _th "iclas.txt real name"
      _th "iclas.txt public name"
      _th 'cn'
      _th 'givenName'
      _th 'Modify?'
      _th 'sn'
      _th 'Modify?'
    end

    people.sort_by(&:name).each do |p|
      next if p.banned?
      given = p.givenName rescue '---' # some entries have not set this up

      # Match the name as a word-bounded string (but allow for trailing . which is not a word char)
      givenOK = (p.cn.match(/\b#{Regexp.quote(given)}(\s|$)/) != nil)
      badGiven += 1 unless givenOK

      # surnames don't tend to end with .
      snOK =    (p.cn.match(/\b#{Regexp.quote(p.sn)}\b/) != nil)
      badSN += 1 unless snOK

      if givenOK and snOK # all checks OK
        matches += 1
        next
      end
      next if givenOK and skipSN

      new_given = '???'
      new_sn = '???'
      names = p.cn.split(' ')
      if names.size == 2
        new_given = names[0]
        new_sn = names[1]
      elsif names.size == 4
        if names[1..2] == %w(de la) or names[1..2] == %w(van der)
          new_given = names.shift
          new_sn = names.join(' ')
        end
      elsif names.size == 3
        if names[1] == 'van' or names[1] == 'de' or names[1] == 'le'
          new_given = names.shift
          new_sn = names.join(' ')
        elsif names[1] =~ /^[A-Z]\.$/ or names[1] =~ /^[A-NP-Z]$/ # James A. Taylor or Jon B Goode (not Jack O Connor)
          new_given = names.shift
          new_sn = names.pop
        end
      end
      icla = ASF::ICLA.find_by_id(p.uid)
      claRef = icla.claRef if icla
      claRef ||= 'unknown'
      _tr do
        _td do
          _a p.uid, href: '/roster/committer/' + p.uid
        end
        _td do
          file = ASF::ICLAFiles.match_claRef(claRef.untaint)
          if file
            _a claRef, href: "https://svn.apache.org/repos/private/documents/iclas/#{file}"
          else
            _ claRef
          end
        end
        _td (icla.legal_name rescue '?')
        _td (icla.name rescue '?')
        _td p.cn
        _td do
          if givenOK
            _ given
          else
            _em given
          end
        end
        _td! copyAble: 'true' do
          if givenOK
            _ ''
          else
              if given == p.uid or given == '---' or given == p.cn
                _ new_given # likely to be correct
              else
                _em new_given # less likely
              end
          end
        end
        _td do
          if snOK
            _ p.sn
          else
            _em p.sn
          end
        end
        _td! copyAble: 'true' do
          if snOK
            _ ''
          else
            if p.sn == p.uid or p.sn == p.cn
              _ new_sn
            else
              _em new_sn
            end
          end
        end
      end
    end
  end

  _p do
    _ "Total: #{people.size} Matches: #{matches} GivenBad: #{badGiven} SNBad: #{badSN}"
  end

  #################################################################### 
  #                   Form used to submit changes                    #
  #################################################################### 
  
  _form_ method: 'post' do
    _input type: 'hidden', name: 'updates'
    _input type: 'submit', value: 'Commit Changes', disabled: true
  end
 end

  #################################################################### 
  #                        Client side logic                         #
  #################################################################### 
  
  _script do
  
    # enable submit button only when there are modifications
    def enable_submit()
      button = document.querySelector('input[type=submit]')
      modified = document.querySelectorAll('td.modified')
  
      button.disabled = (modified.length == 0)
    end
  
    Array(document.getElementsByTagName('td')).each do |td|
      next unless td.getAttribute('copyAble') == 'true'
      # double-click: copy to previous cell
      td.addEventListener(:dblclick) do |event|
        cell = event.target
        cell = cell.parentNode if cell.nodeName != 'TD'
        txt = cell.textContent
        return if txt == '???'
        row = cell.parentNode
        col = cell.cellIndex
        pes = row.children[col-1]
        pes.innerText = txt
        pes.classList.add 'modified'
        enable_submit()
      end
    end
  
    # capture modifications when button is pressed
    document.querySelector('input[type=submit]').addEventListener(:click) do
      updates = {}
      # Must agree with number of columns in the main table above
      columnNames = %w(uid icla_file legal_name public_name cn givenName newGiven sn newSN)
  
      Array(document.querySelectorAll('td.modified')).each do |td|
        id = td.parentNode.firstElementChild.textContent.strip()
        updates[id] ||= {}
        updates[id][columnNames[td.cellIndex]] = td.textContent
      end
  
      document.querySelector('form input').value = JSON.stringify(updates)
    end
  
    # force submit state on initial load (i.e., disable submit button)
    enable_submit()
  end

end