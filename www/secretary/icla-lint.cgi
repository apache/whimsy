#!/usr/bin/env ruby

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

require 'wunderbar/script'
require 'ruby2js/filter/functions'
require 'whimsy/asf'

ldaplist = ASF::Person.list
ldap = ldaplist.map(&:id)
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
    _label "#{ldaplist.length} entries found."
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

  _h2_ 'Issues'

  input = File.join(ASF::SVN['officers'], 'iclas.txt')
  iclas = Hash[Dir[File.join(ASF::SVN['iclas'], '*')].map do |file|
    [File.basename(file).sub(/\.\w+$/, ''), File.basename(file)]
  end]

  _table_ do
    _tr do
      _th 'availid'
      _th 'public name'
      _th 'issue'
      _th 'email'
      _th 'ICLA stub'
    end

    document = File.read(input).untaint
    document.scan(/^(\w.*?):.*?:(.*?):(.*?):(.*)/) do |(id, name, email, comment)|
      issue, note = nil, nil
      comment2 = comment.dup

      if comment.sub!(/\s*(\(.*?\))\s*/, '')
        issue, note = 'comment', "parenthetical comment: #{$1.inspect}"
      end

      if comment.sub!(/Signed CLA(.+?);/, 'Signed CLA;')
        issue, note = 'extra', "extra text: #{$1.inspect}"
      end

      if id != 'notinavail'
        apachemail = "," + id + "@apache.org"
      end

      # check LDAP independently; may be overridden by issues with comment field
      if id != 'notinavail' and ldap.length > 0 and not ldap.include? id
        issue, note = 'notinldap', 'not in LDAP'
      end
      if comment =~ /Signed CLA;(.*)/
        # to be valid, the entry must exist; remove matched entries
        missing = $1.split(',').select {|path|  iclas.delete(path) == nil}

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
  
  if iclas.size > 0
    _h2_ 'ICLA files not matched against iclas.txt'
    _table do
      _tr do
        _th 'stem'
      end
      iclas.each do |k,v|
        _tr do
          _td do
            _a k, href: "https://svn.apache.org/repos/private/documents/iclas/#{v}"
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
