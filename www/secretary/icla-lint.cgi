#!/usr/bin/ruby1.9.1
require 'wunderbar/script'
require 'ruby2js/filter/functions'
require 'whimsy/asf'

_html do
  _h1 'iclas.txt lint check'

  _h2_ 'Show'
  _div do
    _input id: 'missing', type: 'checkbox', checked: true
    _label 'missing stub/dir name', for: 'missing'
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
    _label 'document not found', for: 'error'
  end

  _div do
    _input id: 'mismatch', type: 'checkbox', checked: true
    _label "doesn't match pattern", for: 'mismatch'
  end

  _div do
    _input id: 'notinavail', type: 'checkbox', checked: true
    _label "notinavail entries", for: 'notinavail'
  end

  _h2_ 'Issues'

  input = ASF::SVN['private/foundation/officers'] + '/iclas.txt'
  iclas = Dir[ASF::SVN['private/documents/iclas'] + '/*'].map do |file|
    file.split('/').last.sub(/\.\w+$/, '')
  end

  _table_ do
    _tr do
      _th 'availid'
      _th 'public name'
      _th 'issue'
      _th 'field 5'
    end

    document = File.read(input).untaint
    document.scan(/^(\w.*?):.*?:(.*?):.*:(.*)/) do |(id, name, comment)|
      issue, note = nil, nil
      comment2 = comment.dup

      if comment.sub!(/\s*(\(.*?\))\s*/, '')
        issue, note = 'comment', "parenthetical comment: #{$1.inspect}"
      end

      if comment.sub!(/Signed CLA(.+?);/, 'Signed CLA;')
        issue, note = 'extra', "extra text: #{$1.inspect}"
      end

      if comment =~ /Signed CLA;(.*)/
        missing = $1.split(',').select {|path| not iclas.include? path}

        if not missing.empty?
          missing = missing.select do |path|
            not iclas.any? {|icla| icla.start_with? path}
          end
        end

        if not missing.empty?
          issue, note = 'error', "document not found: #{missing.first.inspect}"
        end
      elsif comment =~ /^Treasurer;/ or comment =~ /^President;/

      elsif comment == 'Signed CLA'
        issue, note = 'missing', 'missing stub/dir name'
      else
        issue, note = 'mismatch', "doesn't match pattern"
      end

      if issue
        issue = "#{issue} notinavail" if id =='notinavail'

        _tr_ class: issue do
          _td! do
            if id == 'notinavail'
              _ id
            else
              _a id, href: 'https://whimsy.apache.org/roster/committer/' + id
            end
          end

          if id != 'notinavail' and ASF::Person.new(id).asf_member?
            _td! {_b name}
          else
            _td name
          end

          _td note
          _td comment2
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
        for j in 0...rows.length
          if event.target.checked
            rows[j].style.display = ''
          else
            rows[j].style.display = 'none'
          end
        end
      end
    end
  end
end
