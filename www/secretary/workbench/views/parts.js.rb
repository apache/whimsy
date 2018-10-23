#
# Parts list for a message: shows attachments, handles context
# menus and drag and drop, and hosts forms.
#

class Parts < Vue
  def initialize
    @selected = nil
    @busy = false
    @attachments = []
    @drag = nil
    @form = :categorize
    @menu = nil
    @project = nil
  end

  ########################################################################
  #                     HTML rendering of this frame                     #
  ########################################################################

  def render
    # common options for all list items
    options = {
      attrs: {draggable: 'true'},
      on: {
        dragstart: self.dragStart,
        dragenter: self.dragEnter,
        dragover: self.dragOver,
        dragleave: self.dragLeave,
        dragend: self.dragEnd,
        drop: self.drop,
        contextmenu: self.showMenu,
        click: self.select
      }
    }

    # locate corresponding signature file (if any)
    signature = CheckSignature.find(@selected, @attachments)

    # list of attachments
    _ul.attachments! @attachments, ref: 'attachments' do |attachment|
      if attachment == @drag
        options[:class] = 'dragging'
      elsif attachment == @selected
        options[:class] = 'selected'
      elsif attachment == signature
        options[:class] = 'signature'
      else
        options[:class] = nil
      end

      if attachment =~ /\.(pdf|txt|jpeg|jpg|gif|png)$/i
        link = "./#{encodeURIComponent(attachment)}"
      else
        link = "_danger_/#{encodeURIComponent(attachment)}"
      end

      _li options do
        _a attachment, href: link, target: 'content', draggable: 'false',
          onClick: self.navigate
      end
    end

    if @headers and @headers.secmail and @headers.secmail.status
      _div.alert.alert_info @headers.secmail.status
    end

    if @headers and @headers.secmail and @headers.secmail.notes
      _div.alert.alert_warning do
        _h5 'Notes:'
        _span @headers.secmail.notes
      end
    end

    # context menu that displays when you 'right click' an attachment
    _ul.contextMenu do
      _li "\u2704 burst", onMousedown: self.burst
      _li.divider
      _li "\u21B7 right", onMousedown: self.rotate_attachment
      _li "\u21c5 flip", onMousedown: self.rotate_attachment
      _li "\u21B6 left", onMousedown: self.rotate_attachment
      _li.divider
      _li "\u2716 delete", onMousedown: self.delete_attachment
      _li "\u2709 pdf-ize", onMousedown: self.pdfize
    end

    if @selected and not @menu and @selected !~ /\.(asc|sig)$/

      _CheckSignature selected: @selected, attachments: @attachments,
        headers: @headers

      _ul.nav.nav_tabs do
        _li class: ('active' unless [:edit, :mail].include?(@form)) do
          _a 'Categorize', onMousedown: self.tabSelect
        end
        _li class: ('active' if @form == :edit) do
          _a 'Edit', onMousedown: self.tabSelect
        end
        _li class: ('active' if @form == :mail) do
          _a 'Mail', onMousedown: self.tabSelect
        end
      end

      if @form == :categorize

        # filing options
        _div.doctype do
          _label do
            _input type: 'radio', name: 'doctype', value: 'icla',
              onClick: -> {@form = ICLA}
            _span 'icla'
          end

          _label do
            _input type: 'radio', name: 'doctype', value: 'icla2',
              onClick: -> {@form = ICLA2}
            _span 'additional icla'
          end

          _label do
            _input type: 'radio', name: 'doctype', value: 'ccla',
              onClick: -> {@form = CCLA}
            _span 'ccla'
          end

          _label do
            _input type: 'radio', name: 'doctype', value: 'grant',
              onClick: -> {@form = Grant}
            _span 'software grant'
          end

          if @@meeting
            _label do
              _input type: 'radio', name: 'doctype', value: 'mem',
                onClick: -> {@form = MemApp}
              _span 'membership application'
            end
          end

          _hr

          # reject message with message
          _form method: 'POST', target: 'content' do
            _input type: 'hidden', name: 'message',
              value: window.parent.location.pathname
            _input type: 'hidden', name: 'selected', value: @@selected
            _input type: 'hidden', name: 'signature', value: @@signature

            _label do
              _input type: 'radio', name: 'doctype', value: 'incomplete',
                onClick: self.reject
              _span 'incomplete form'
            end

            _label do
              _input type: 'radio', name: 'doctype', value: 'unsigned',
                onClick: self.reject
              _span 'unsigned form'
            end

            _label do
              _input type: 'radio', name: 'doctype', value: 'pubkey',
                onClick: self.reject
              _span 'upload public key'
            end

            _label do
              _span 'project: '
              _select name: 'project', value: @project, disabled: @filed do
                _option ''
                @@projects.each do |project|
                  _option project
                end
              end
            end
          end

          _hr

          _label do
            _input type: 'radio', name: 'doctype', value: 'forward',
              onClick: -> {@form = Forward}
            _span 'forward email'
          end

          _hr

          _label do
            _input type: 'radio', name: 'doctype', value: 'forward',
              onClick: -> {@form = Note}
            if @headers and @headers.secmail and @headers.secmail.notes
              _span 'edit note'
            else
              _span 'add note'
            end
          end
        end

      elsif @form == :edit

        _ul.editPart! do
          _li "\u2704 burst", onMousedown: self.burst
          _li.divider
          _li "\u21B7 right", onMousedown: self.rotate_attachment
          _li "\u21c5 flip", onMousedown: self.rotate_attachment
              _li "\u21B6 left", onMousedown: self.rotate_attachment
          _li.divider
          _li "\u2716 delete", onMousedown: self.delete_attachment
          _li "\u2709 pdf-ize", onMousedown: self.pdfize
        end

      elsif @form == :mail

        _div.partmail! do
          _h3 'cc'
          _textarea value: @cc, name: 'cc'

          _h3 'bcc'
          _textarea value: @bcc, name: 'bcc'

          _button.btn.btn_primary 'Save', onClick: self.update_mail
        end

      else

        Vue.createElement @form, props: {
          headers: @headers,
          selected: @selected,
          projects: @@projects,
          signature: signature
        }
      end
    end
  end

  ########################################################################
  #                            Tab selection                             #
  ########################################################################

  def tabSelect(event)
    @form = event.currentTarget.textContent.downcase()
    jQuery('.doctype input').prop('checked', false)
  end

  ########################################################################
  #                           React lifecycle                            #
  ########################################################################

  # initial list of attachments comes from the server; may be updated
  # by context menu actions.
  def beforeMount()
    @attachments = @@attachments
  end

  # register mouse and keyboard handlers, hide context menu
  def mounted()
    window.onmousedown = self.hideMenu

    # register keyboard handler on parent window and all frames
    window.parent.onkeydown = self.keydown
    frames = window.parent.frames
    for i in 0...frames.length
      begin
        frames[i].onkeydown=self.keydown
      rescue => error
      end
    end

    self.hideMenu()

    self.extractHeaders(@@headers)

    window.addEventListener 'message', self.status_update

    # add click handler on all non-part links.  Note: part links may
    # change, and click handlers are established above
    parts = Array(document.querySelectorAll('#parts a[target=content'))
    Array(document.querySelectorAll('a[target=content')).each do |link|
      next if parts.include? link
      link.onclick = self.navigate
    end

    # when back button is clicked, go all of the way back
    history_length =  window.history.length
    window.addEventListener 'popstate' do |event|
      window.history.go(history_length - window.history.length)
    end

    self.extractHeaders(@@headers)
  end

  def extractHeaders(headers)
    @cc = (headers.cc || []).join("\n")
    @bcc = (headers.bcc || []).join("\n")
    @headers = headers
  end

  def updated()
    if @busy
      document.body.classList.add 'busy'
    else
      document.body.classList.remove 'busy'
    end
  end

  ########################################################################
  #                             Context menu                             #
  ########################################################################

  # position and show context menu
  def showMenu(event)
    @menu = event.currentTarget.textContent
    menu = document.querySelector('.contextMenu')
    menu.style.position = :absolute
    menu.style.display = :block

    bodyRect = document.body.getBoundingClientRect()
    menuRect = menu.getBoundingClientRect()
    position = {x: event.clientX, y: event.clientY}

    if position.x + menuRect.width > bodyRect.width
      position.x -= menuRect.width if position.x >= menuRect.width
    end

    if position.y + menuRect.height > bodyRect.height
      position.y -= menuRect.height if position.y >= menuRect.height
    end

    menu.style.left = position.x + 'px'
    menu.style.top = position.y + 'px'
    event.preventDefault()
  end

  # hide context menu whenever a click is received outside the menu
  def hideMenu(event)
    target = event && event.target
    while target
      return if target.class == 'contextMenu'
      target = target.parentNode
    end

    document.querySelector('.contextMenu').style.display = :none

    @menu = nil
    @busy = false
  end

  # N.B. @selected is an encoded URI; @menu is not encoded

  # burst a PDF into individual pages
  def burst(event)
    data = {
      selected: @menu || decodeURI(@selected),
      message: window.parent.location.pathname
    }

    @busy = true
    HTTP.post('../../actions/burst', data).then {|response|
      @attachments = response.attachments
      self.selectPart response.selected
      self.hideMenu()
      window.parent.frames.content.location.href=response.selected
    }.catch {|error|
      alert error
      self.hideMenu()
    }
  end

  # delete an attachment
  def delete_attachment(event)
    data = {
      selected: @menu || decodeURI(@selected),
      message: window.parent.location.pathname
    }

    @busy = true
    HTTP.post('../../actions/delete-attachment', data).then {|response|
      @attachments = response.attachments
      if event.type == 'message'
        signature = CheckSignature.find(@selected, response.attachments)
        @busy = false
        @selected = signature
        self.delete_attachment(event) if signature
      elsif response.attachments and not response.attachments.empty?
        self.hideMenu()
        window.parent.frames.content.location.href='_body_'
      else
        window.parent.location.href = '../..'
      end
    }.catch {|error|
      alert error
      self.hideMenu()
    }
  end

  # rotate an attachment
  def rotate_attachment(event)
    message = window.parent.location.pathname

    data = {
      selected: @menu || decodeURI(@selected),
      message: message,
      direction: event.currentTarget.textContent
    }

    @busy = true
    HTTP.post('../../actions/rotate-attachment', data).then {|response|
      @attachments = response.attachments
      self.selectPart response.selected
      self.hideMenu()

      # reload attachment in content pane
      window.parent.frames.content.location.href = response.selected
    }.catch {|error|
      alert error
      self.hideMenu()
    }
  end

  # convert an attachment to pdf
  def pdfize(event)
    message = window.parent.location.pathname

    data = {
      selected: @menu || decodeURI(@selected),
      message: message
    }

    @busy = true
    HTTP.post('../../actions/pdfize', data).then {|response|
      @attachments = response.attachments
      self.selectPart response.selected
      self.hideMenu()

      # reload attachment in content pane
      window.parent.frames.content.location.href = response.selected
    }.catch {|error|
      alert error
      self.hideMenu()
    }
  end

  ########################################################################
  #                             Update email                             #
  ########################################################################

  def update_mail(event)
    event.target.disabled = true

    jQuery.ajax(
      type: "POST",
      url: "../../actions/update-mail",
      data: {
        message: window.parent.location.pathname,
        cc: @cc,
        bcc: @bcc
      },
      dataType: 'json',
      success: ->(data) { self.extractHeaders(data.headers) },
      complete: -> { event.target.disabled = false }
    )
  end

  ########################################################################
  #                         Reject attachment                            #
  ########################################################################

  def reject(event)
    form = jQuery(event.target).closest('form')
    form.attr('action', "../../tasklist/#{event.target.value}")
    form.submit()
  end

  ########################################################################
  #                            Miscellaneous                             #
  ########################################################################

  # clicking on an attachment selects it
  def select(event)
    self.selectPart event.currentTarget.querySelector('a').getAttribute('href')
  end

  # if selection changes, reset form and radio buttons
  def selectPart(part)
    part = part.split('/').pop()
    if @selected != part
      @selected = part
      @form = :categorize

      Array(document.querySelectorAll('input[type=radio]')).each do |button|
        button.checked = false
      end
    end
  end

  # handle keyboard events
  def keydown(event)
    if event.keyCode == 8 or event.keyCode == 46 # backspace or delete
      if event.metaKey or event.ctrlKey
        @busy = true
        event.stopPropagation()

        pathname = window.parent.location.pathname
        HTTP.delete(pathname).then {
          Status.pushDeleted pathname
          window.parent.location.href = '../..'
        }.catch {|error|
          alert error
          @busy = false
        }
      elsif !%w(input textarea).include? event.target.tagName.downcase()
        window.parent.location.href = '../..'
      end
    elsif event.keyCode == 38 # up
      window.parent.location.href = '../..'
    elsif event.keyCode == 13 # enter/return
      event.stopPropagation()
    end
  end

  # tasklist completion events
  def status_update(event)
    if event.data.status == 'complete'
      self.delete_attachment(event)
    elsif event.data.status == 'keep'
      @selected = nil
      @form = :categorize
      self.extractHeaders event.data.headers if event.data.headers
    end
  end

  ########################################################################
  #                          drag/drop support                           #
  ########################################################################
  #
  # Note: support varies by browser (in particular, when events are called
  # and whether or not a particular event has access to dataTransfer data.)
  # Accordingly, the below is coded in a way that is mildly redundant and
  # uses React.js state data in lieu of dataTransfer.  Oddly, with some
  # browsers, drag and drop isn't possible without setting something in
  # dataTransfer, so that data is set too, even though it is not used.
  #

  # start by capturing the 'href' attribute
  def dragStart(event)
    @drag = event.currentTarget.querySelector('a').getAttribute('href')
    event.dataTransfer.setData('text', @drag)
  end

  # show item as valid drop target when a dragged element is over it
  def dragEnter(event)
    href = event.currentTarget.querySelector('a').getAttribute('href')
    if @drag and @drag != href
      event.currentTarget.classList.add 'drop-target'
    end
  end

  # check for valid drag/drop operations (different href)
  def dragOver(event)
    href = event.currentTarget.querySelector('a').getAttribute('href')
    if @drag and @drag != href
      event.currentTarget.classList.add 'drop-target'
      event.preventDefault()
    end
  end

  # unmark item as selected when a dragged element is no longer over it
  def dragLeave(event)
    event.currentTarget.classList.remove 'drop-target'
  end

  # complete drop operation
  def drop(event)
    target = event.currentTarget
    href = target.querySelector('a').getAttribute('href')
    event.preventDefault()

    data = {
      source: decodeURI(@drag.split('/').pop()),
      target: decodeURI(href.split('/').pop()),
      message: window.parent.location.pathname
    }

    @busy = true
    @drag = nil
    HTTP.post('../../actions/drop', data).then {|response| 
      @busy = false
      @attachments = response.attachments
      self.selectPart response.selected
      target.classList.remove 'drop-target'
      window.parent.frames.content.location.href=response.selected
    }.catch {|error|
      alert error
      @busy = false
    }
  end

  # cancel drag operation
  def dragEnd(event)
    @drag = nil
  end

  # implement content navigation using the history API
  def navigate(event)
    destination = event.target.attributes['href'].value
    window.parent.frames.content.history.replaceState({}, nil, destination)
  end
end
