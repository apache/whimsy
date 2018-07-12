#!/usr/bin/env ruby

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

require 'wunderbar/script'
require 'ruby2js/filter/functions'
require 'whimsy/asf'

ldap = ASF::Person.listids
errors = 0

_html do
  _style %{
    table {border-collapse: collapse}
    table, th, td {border: 1px solid black}
    td {padding: 3px 6px}
    tr:hover td {background-color: #FF8}
    th {background-color: #a0ddf0}
  }

  _h1 'iclas.txt lint check'

  _h2_ 'LDAP Status'
  _div do 
    _label "#{ldap.length} entries found."
   end

  _h2_ 'Error Status'
  _div do
    _label "#{errors} errors found."
   end

  _h2_ 'Show'
  _div do
    _input id: 'missing', type: 'checkbox', checked: true
    _label 'missing stub/dir name after Signed CLA', for: 'missing'
  end

  _div do
    _input id: 'extra', type: 'checkbox', checked: true
    _label 'extra text', for: 'extra'
  end

  _div do
    _input id: 'comment', type: 'checkbox', checked: true
    _label 'parenthetical comment', for: 'comment'
  end

  _div do
    _input id: 'error', type: 'checkbox', checked: true
    _label 'icla not found', for: 'error'
  end

  _div do
    _input id: 'mismatch', type: 'checkbox', checked: true
    _label "doesn't match pattern", for: 'mismatch'
  end

  _div do
    _input id: 'notinldap', type: 'checkbox', checked: true
    _label "id not in LDAP people", for: 'notinldap'
  end

  _div do
    _input id: 'notinavail', type: 'checkbox', checked: true
    _label "notinavail entries", for: 'notinavail'
  end

  iclas = Hash.new{|h,k| h[k]=[]}
  dupes=0
  Dir[File.join(ASF::SVN['iclas'], '*')].each do |file|
    name = File.basename(file)
    stem = name.sub(/\.\w+$/, '')
    dupes += 1 if iclas.has_key? stem
    iclas[stem] << name
  end

  if dupes > 0
    _h2_ 'Files with duplicate stems'
    _table_ do
      _tr do
        _th 'stem'
        _th 'paths'
      end
      iclas.each do |icla,paths|
        if paths.size > 1
          _tr do
            _td icla
            _td do
              paths.each do |path|
                _a path, href: "https://svn.apache.org/repos/private/documents/iclas/#{path}"
              end
            end
          end
        end
      end      
    end
  end

  seen=Hash.new(0) # iclas.txt CLA stem values
  icla_ids=Hash.new{ |h,k| h[k] = []} # to check for duplicates and missing entries
  icla_mails=Hash.new{ |h,k| h[k] = []} # to check for duplicates

  _h2_ 'Issues'

  _table_ do
    _tr do
      _th 'availid'
      _th 'public name'
      _th 'issue'
      _th 'email'
      _th 'ICLA stub'
    end

    input = File.join(ASF::SVN['officers'], 'iclas.txt')
    document = File.read(input).untaint
    document.scan(/^((\w.*?):.*?:(.*?):(.*?):(.*))/) do |(line, id, name, email, comment)|
      issue, note = nil, nil
      comment2 = comment.dup
      claRef = nil

      if comment.sub!(/\s*(\(.*?\))\s*/, '')
        issue, note = 'comment', "parenthetical comment: #{$1.inspect}"
      end

      if comment.sub!(/Signed CLA(.+?);/, 'Signed CLA;')
        issue, note = 'extra', "extra text: #{$1.inspect}"
      end

      if id != 'notinavail'
        icla_ids[id] << line
        apachemail = "," + id + "@apache.org"
      end

      # check LDAP independently; may be overridden by issues with comment field
      if id != 'notinavail' and ldap.length > 0 and not ldap.include? id
        issue, note = 'notinldap', 'not in LDAP'
      end
      if comment =~ /Signed CLA;(.*)/
        claRef = $1
        # to be valid, the entry must exist; remove matched entries
        missing = claRef.split(',').select {|path| seen[path] += 1; iclas.delete(path) == nil}

        if not missing.empty?
          issue, note = 'error', "missing icla: #{missing.first.inspect}"
        end
      elsif comment =~ /^Treasurer;/ or comment =~ /^President;/

      elsif comment == 'Signed CLA'
        issue, note = 'missing', 'missing stub/dir name'
      elsif comment.start_with? 'disabled;'
        unless ASF::Person.new(id).banned?
          issue, note = 'mismatch', "LDAP entry not marked disabled"
        end
      else
        issue, note = 'mismatch', "comment doesn't match pattern"
      end

      icla_mails[email] << [id, claRef, line]

      if issue
        issue = "#{issue} notinavail" if id =='notinavail'

        _tr_ class: issue do
          _td! do
            if id == 'notinavail' or issue == 'notinldap'
              _ id
            else
              _a id, href: '/roster/committer/' + id
            end
          end

          if id != 'notinavail' and ASF::Person.new(id).asf_member?
            _td! {_b name}
          else
            _td name
          end

          _td do
            _button 'email', data_email: "#{name} <#{email}>#{apachemail}",
              data_issue: note, data_name: name
            _span note
          end

          _td email
          _td comment2
        end
      end
    end
  end

  # select entries with count != 1  
  seen.select! {|k,v| v != 1}
  if seen.size > 0
    _h2_ 'Duplicate stem entries in iclas.txt'
    _table_ do
      _tr do
        _th 'stem'
        _th 'count'
      end
      seen.each do |k,v|
        _tr do
          _td k
          _td v
        end
      end
    end # table
  end

  if iclas.size > 0
    _h2_ 'ICLA files not matched against iclas.txt'
    _table do
      _tr do
        _th 'stem'
      end
      iclas.each do |k,v|
        v.each do |p|
          _tr do
            _td do
              _a k, href: "https://svn.apache.org/repos/private/documents/iclas/#{p}"
            end
          end
        end
      end
    end
  end

  #  Check if there are any duplicate ids
  dups=icla_ids.select{|k,v| v.size > 1}
  if dups.size > 0
    _h2_ 'Duplicate availids in iclas.txt'
    _table do
      _tr do
        _th 'Availid'
        _th 'Entry'
      end
      dups.each do |k,v|
        v.each do |l|
          _tr do
            _td k
            _td l
          end
        end
      end
    end
  end

  # Check that all LDAP entries appear in iclas.txt
  no_icla = ldap.select {|k| not icla_ids.has_key? k}
  # remove known exceptions
  %w(testsebb testrubys apldaptest).each {|w| no_icla.delete w}
  if no_icla.size > 0
    _h2 'LDAP entries not listed in iclas.txt'
    _table_ do
      _tr do
        _th 'Availid'
        _th 'committer'
      end
      no_icla.each do |k|
        _tr do
          _td k
          _td do
            _a k, href: '/roster/committer/' + k
          end
        end
      end
    end
  end

  #  Check if there are any duplicate mails
  mdups=icla_mails.select{|k,v| v.size > 1}
  if mdups.size > 0
    _h2_ 'Duplicate mails in iclas.txt'
    _table do
      _tr do
        _th 'Email'
        _th 'Availid'
        _th 'ICLA'
        _th 'Entry'
      end
      mdups.each do |k,v|
        v.each do |l|
          id_, icla_, line_ = l
          _tr do
            _td k
            _td do
              if id_ != 'notinavail'
                _a id_, href: '/roster/committer/' + k
              else
                _ id_
              end
            end
            _td do
              file = ASF::ICLAFiles.match_claRef(icla_)
              if file
                _a icla_, href: "https://svn.apache.org/repos/private/documents/iclas/#{file}"
              else
                _ icla_
              end
            end
            _td line_
          end
        end
      end
    end
  end

  _script do
    inputs = document.querySelectorAll('input')
    for i in 0...inputs.length
      inputs[i].checked = true
      inputs[i].addEventListener('click') do |event|
        rows = document.getElementsByClassName(event.target.id)
        errors = rows.length
        for j in 0...rows.length
          if event.target.checked
            rows[j].style.display = ''
          else
            rows[j].style.display = 'none'
          end
        end
      end
    end
    buttons = document.querySelectorAll('button')
    for i in 0...buttons.length
      buttons[i].addEventListener('click') do |event|
        email = event.target.getAttribute('data-email')
        issue = event.target.getAttribute('data-issue')
        name  = event.target.getAttribute('data-name')

        destination = "mailto:#{email}?cc=secretary@apache.org"
        subject = 'Your Apache ICLA has gone missing'
        body = "Dear " + name + ",\n\n" +
            "We are reviewing our records to be sure that all submitted ICLAs are on file.\n" +
            "Unfortunately, we are unable to locate the ICLA that you submitted earlier.\n\n" +
            "Can you please resubmit to secretary@apache.org? http://apache.org/licenses/#submitting\n" +
            "Please do *not* use an apache email as your E-Mail address.\n" +
            "You can send the original ICLA (if the email address is still valid) or a new one.\n\n" +
            "Best regards,\n"

        window.location = destination +
          "&subject=#{encodeURIComponent(subject)}" +
          "&body=#{encodeURIComponent(body)}"

      end
    end

  end
end
