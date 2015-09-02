#!/usr/bin/ruby1.9.1

require 'whimsy/asf'
require 'wunderbar/script'

# only available to ASF members and PMC chairs
user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

_html do
  _style %{
    table {border-collapse: collapse}
    table, th, td {border: 1px solid black}
    td {padding: 3px 6px}
    th {background-color: #a0ddf0}

    td[draggable=true] {cursor: move}
    td.modified {background-color: #FF0}
    td.over {background-color: #FFA}

    input[type=submit] {margin-top: 1em}
  }

  _h1 "public names: LDAP vs ICLA.txt"

  if @updates
    _pre JSON.pretty_generate(JSON.parse(@updates))
  end

  #################################################################### 
  #                           Instructions                           #
  #################################################################### 

  _h2_ 'Instructions:'

  _ul do
    _li 'Click to edit.'
    _li 'Drag/drop to copy.'
    _li 'When done, click "Submit Updates" (at the bottom of the page).'
  end

  #################################################################### 
  #     Show LDAP differences where entry is present in icla.txt     #
  #################################################################### 

  # prefetch data
  ASF::Person.preload('cn')
  ASF::ICLA.preload

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
      next unless person.dn

      if person.cn != name
        _tr_ do
          _td do
            _a id, href: "https://whimsy.apache.org/roster/committer/#{id}"
          end
          _td legal_name, draggable: 'true'
          _td name, draggable: 'true'
          _td person.cn, draggable: 'true'
        end
      end
    end
  end

  #################################################################### 
  #   Show LDAP differences where entry is NOT present in icla.txt   #
  #################################################################### 

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

        _tr do
          _td do
            _a person.id, href:
              "https://whimsy.apache.org/roster/committer/#{person.id}"
          end
          _td person.cn
          _td person.mail
        end
      end
    end
  end

  #################################################################### 
  #                   Form used to submit changes                    #
  #################################################################### 

  _form method: 'post' do
    _input type: 'hidden', name: 'updates'
    _input type: 'submit', value: 'Commit Changes', disabled: true
  end

  #################################################################### 
  #                        Client side logic                         #
  #################################################################### 

  _script do
    # track current drag operation
    row = nil
    dragText = nil

    # enable submit button only when there is modifications
    def enable_submit()
      button = document.querySelector('input[type=submit]')
      modified = document.querySelectorAll('td.modified')

      button.disabled = (modified.length == 0)
    end

    # add drag/drop, mouse click event handlers to cells marked as draggable
    tds = document.getElementsByTagName('td')
    for i in 0...tds.length
      td = tds[i]
      next unless td.getAttribute('draggable') == 'true'

      # dragstart: capture row and textContent
      td.addEventListener('dragstart') do |event|
        row = event.target.parentNode
        dragText = this.textContent
        event.dataTransfer.setData('text/plain', dragText)
      end

      # dragover: add CSS class 'over' if same row and text is different
      td.addEventListener('dragover') do |event|
        return unless row == event.target.parentNode
        if event.target.textContent != dragText
          event.target.classList.add 'over'
          event.preventDefault() 
        end
      end

      # dragleave: remove CSS class 'over'
      td.addEventListener('dragleave') do |event|
        event.currentTarget.classList.remove 'over'
      end

      # drop: update text after capturing original text
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
        enable_submit()
        row = nil
      end

      # mouseup: replace cell with an input field
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

        # when focus leaves input, replace cell with modified text
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

          enable_submit()
        end
      end
    end

    # capture modifications when button is pressed
    document.querySelector('input[type=submit]').addEventListener('click') do
      updates = {}
      cols = %w(id legal_name public_name ldap)

      tds = document.querySelectorAll('td.modified')
      for i in 0...tds.length
        td = tds[i]
        id = td.parentNode.firstElementChild.textContent.trim()
        updates[id] ||= {}
        updates[id][cols[td.cellIndex]] = td.textContent
      end

      input = document.querySelector('form input')
      input.value = JSON.stringify(updates)
    end
  end
end
