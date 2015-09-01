#!/usr/bin/ruby1.9.1

require 'whimsy/asf'
require 'wunderbar/script'

user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user or $USER=='ea'
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

ASF::Person.preload('cn')
ASF::ICLA.preload

_html do
  _style %{
    td[draggable=true] {cursor: move}
    td.over {border: dashed 1px green}
    td.modified {background-color: #FF0}
    button {margin-top: 1em}
    pre {min-height: 3em}
  }

  _h1 "public names: LDAP vs ICLA.txt"

  _h2_ 'Instructions'

  _p do
    _b 'Note:'
    _span 'At the moment, this is a demo only'
  end

  _ul do
    _li 'Click to edit'
    _li 'Drag/drop to copy'
    _li 'Click "Show Updates" (at the bottom of the page) to see what ' +
      'updates would be submitted.'
  end

  _h2!.present! do
    _ 'Present in '
    _a 'icla.txt', 
      href: 'https://svn.apache.org/repos/private/foundation/officers/iclas.txt'
   _ ':'
  end

  _table_ do
    _tr do
      _th "availid"
      _th "icla.txt real name"
      _th "icla.txt public name"
      _th "LDAP cn"
    end

    ASF::ICLA.new.each do |id, legal_name, name, email|
      next if id == 'notinavail'
      person = ASF::Person.find(id)

      if person.attrs['cn'] 
        cn = person.attrs['cn'].first.force_encoding('utf-8')
      else
        cn = nil
      end

      if cn != name
        _tr_ do
          _td do
            _a id, href: "https://whimsy.apache.org/roster/committer/#{id}"
          end
          _td legal_name, draggable: 'true'
          _td name, draggable: 'true'
          _td cn, draggable: 'true'
        end
      end
    end
  end

  icla = ASF::ICLA.availids
  ldap = ASF::Person.list.sort_by(&:name)
  ldap.delete ASF::Person.new('apldaptest')

  unless ldap.all? {|person| icla.include? person.id}
    _h2.missing! 'Only in LDAP'

    _table do
      _tr do
        _th 'id'
        _th 'cn'
        _th 'mail'
      end

      ldap.each do |person|
        next if icla.include? person.id
        cn = person.attrs['cn'].first
        cn.force_encoding 'utf-8' if cn

        mail = person.attrs['mail'].first
        mail.force_encoding 'utf-8' if mail

        _tr do
          _td do
            _a person.id, href:
              "https://whimsy.apache.org/roster/committer/#{person.id}"
          end
          _td cn
          _td mail
        end
      end
    end
  end

  _button 'Show Updates', type: 'button'
  _pre

  _script do
    row = nil

    tds = document.getElementsByTagName('td')
    for i in 0...tds.length
      td = tds[i]
      next unless td.getAttribute('draggable') == 'true'

      td.addEventListener('dragstart') do |event|
        row = event.target.parentNode
        event.dataTransfer.setData('text/plain', this.textContent)
      end

      td.addEventListener('dragover') do |event|
        return unless row == event.target.parentNode
        data = event.dataTransfer.getData('text/plain')
        if data != event.target.textContent
          event.target.classList.add 'over'
          event.preventDefault() 
        end
      end

      td.addEventListener('dragleave') do |event|
        event.currentTarget.classList.remove 'over'
      end

      td.addEventListener('drop') do |event|
        data = event.dataTransfer.getData('text/plain')
        event.target.classList.remove 'over'

        if not event.target.getAttribute('data-original')
          event.target.setAttribute('data-original', event.target.textContent)
          event.target.classList.add 'modified'
        elsif data == event.target.getAttribute('data-original')
          event.target.removeAttribute('data-original')
          event.target.classList.remove 'modified'
        else
          event.target.classList.add 'modified'
        end

        event.target.textContent = data
        event.preventDefault()
        row = nil
      end

      td.addEventListener('mouseup') do |event|
        input = document.createElement('input')
        input.value = event.target.textContent

        if not event.target.getAttribute('data-original')
          event.target.setAttribute('data-original', input.value)
        end

        event.target.firstChild.remove() while event.target.firstChild
        event.target.appendChild(input)
        event.target.setAttribute('draggable', 'false')
        input.focus()
        input.addEventListener('blur') do |event|
          parent = input.parentNode
          value = input.value
          input.remove()
          parent.textContent = value
          parent.setAttribute('draggable', 'true')

          if value == parent.getAttribute('data-original')
            parent.removeAttribute('data-original')
            parent.classList.remove 'modified'
          else
            parent.classList.add 'modified'
          end
        end
      end
    end

    document.getElementsByTagName('button')[0].addEventListener('click') do
      updates = {}
      cols = %w(id legal_name public_name ldap)
      tds = document.querySelectorAll('td.modified')
      for i in 0...tds.length
        td = tds[i]
        id = td.parentNode.firstElementChild.textContent.trim()
        updates[id] = {} unless updates[id]
        updates[id][cols[td.cellIndex]] = td.textContent
      end

      pre = document.getElementsByTagName('pre')[0]
      pre.textContent = JSON.stringify(updates, nil, 2)
    end
  end
end
