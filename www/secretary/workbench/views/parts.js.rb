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
    @missing_address = false
    @missing_email = false
    @corporate_postal = false
    @invalid_public = false
    @separate_signature = false
    @unauthorized_signature = false
    @empty_form = false
    @unreadable_scan = false
    @wrong_identity = false
    @validation_failed = false
    @signature_not_armored = false
    @unsigned = false
    @script_font = false
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
    signature = CheckSignature.find(decodeURIComponent(@selected), @attachments)

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

    if @headers&.secmail&.status
      _div.alert.alert_info @headers.secmail.status
    end

    if @headers&.secmail&.notes
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
      _li "\u2704 revert", onMousedown: self.revert
      _li.divider
      _li "\u2716 delete", onMousedown: self.delete_attachment
      _li "\u2709 pdf-ize", onMousedown: self.pdfize
      _li.divider
      _li "parse pdf", onMousedown: self.pdfparse
    end

    if @selected and not @menu and @selected !~ /\.(asc|sig)$/

      _CheckSignature selected: @selected, attachments: @attachments,
        headers: @headers

      _ul.nav.nav_tabs do
        _li class: ('active' unless %i[edit mail].include?(@form)) do
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

          _label do
            _input type: :radio, name: 'doctype', value: 'emeritus-request',
                   onClick: -> {@form = EmeritusRequest}
            _span 'emeritus request'
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
            if @headers&.secmail&.notes
              _span 'edit note'
            else
              _span 'add note'
            end
          end

          _hr

          _form method: 'POST', target: 'content' do
            _input type: 'hidden', name: 'message',
              value: window.parent.location.pathname
            _input type: 'hidden', name: 'selected', value: @@selected
            _input type: 'hidden', name: 'signature', value: @@signature
            _input type: 'hidden', name: 'missing_address', value: @missing_address
            _input type: 'hidden', name: 'missing_email', value: @missing_email
            _input type: 'hidden', name: 'corporate_postal', value: @corporate_postal
            _input type: 'hidden', name: 'invalid_public', value: @invalid_public
            _input type: 'hidden', name: 'separate_signature', value: @separate_signature
            _input type: 'hidden', name: 'unauthorized_signature', value: @unauthorized_signature
            _input type: 'hidden', name: 'empty_form', value: @empty_form
            _input type: 'hidden', name: 'unreadable_scan', value: @unreadable_scan
            _input type: 'hidden', name: 'wrong_identity', value: @wrong_identity
            _input type: 'hidden', name: 'validation_failed', value: @validation_failed
            _input type: 'hidden', name: 'signature_not_armored', value: @signature_not_armored
            _input type: 'hidden', name: 'unsigned', value: @unsigned
            _input type: 'hidden', name: 'script_font', value: @script_font
            # the above entries must agree with the checked: entries below
            # also any new entries must be added to the backend script incomplete.json.rb

            # Defer processing (must be part of POST block)

            _label do
              _input type: 'radio', name: 'doctype', value: 'pubkey',
                onClick: self.reject
              _span 'upload public key'
            end

            # The reject reason list will grow, so do it last

            _h4 'Reject email with message:'

            _label do
              _span 'Cc project: '
              _select name: 'project', value: @project, disabled: @filed do
                _option ''
                @@projects.each do |project|
                  _option project
                end
              end
            end

            _label do
              _input type: 'radio', name: 'doctype', value: 'incomplete',
                onClick: self.reject
              _span 'reject document (select reasons below)'
            end

            # The checked: variable names must be reflected in the file incomplete.json.jb
            _ul.icla_reject do # the class is used to suppress the leading bullet
              _li do
                _label do
                  _input type: 'checkbox', checked: @missing_address,
                  onClick: -> {@missing_address = !@missing_address}
                  _span ' missing or partial postal address'
                end
              end
              _li do
                _label do
                  _input type: 'checkbox', checked: @missing_email,
                  onClick: -> {@missing_email = !@missing_email}
                  _span ' missing email address'
                end
              end
              _li do
                _label do
                  _input type: 'checkbox', checked: @corporate_postal,
                  onClick: -> {@corporate_postal = !@corporate_postal}
                  _span ' corporate postal address'
                end
              end
              _li do
                _label do
                  _input type: 'checkbox', checked: @invalid_public,
                  onClick: -> {@invalid_public = !@invalid_public}
                  _span ' invalid public name'
                end
              end
              _li do
                _label do
                  _input type: 'checkbox', checked: @separate_signature,
                  onClick: -> {@separate_signature = !@separate_signature}
                  _span ' separate document and signature'
                end
              end
              _li do
                _label do
                  _input type: 'checkbox', checked: @unauthorized_signature,
                  onClick: -> {@unauthorized_signature = !@unauthorized_signature}
                  _span ' unauthorized signature'
                end
              end
              _li do
                _label do
                  _input type: 'checkbox', checked: @empty_form,
                  onClick: -> {@empty_form = !@empty_form}
                  _span ' empty form'
                end
              end
              _li do
                _label do
                  _input type: 'checkbox', checked: @unreadable_scan,
                  onClick: -> {@unreadable_scan = !@unreadable_scan}
                  _span ' unreadable or partial scan'
                end
              end
              _li do
                _label do
                  _input type: 'checkbox', checked: @wrong_identity,
                  onClick: -> {@wrong_identity = !@wrong_identity}
                  _span ' key data does not match email'
                end
              end
              _li do
                _label do
                  _input type: 'checkbox', checked: @validation_failed,
                  onClick: -> {@validation_failed = !@validation_failed}
                  _span ' gpg signature validation failed'
                end
              end
              _li do
                _label do
                  _input type: 'checkbox', checked: @signature_not_armored,
                  onClick: -> {@signature_not_armored = !@signature_not_armored}
                  _span ' gpg signature not armored'
                end
              end
              _li do
                _label do
                  _input type: 'checkbox', checked: @unsigned,
                  onClick: -> {@unsigned = !@unsigned}
                  _span ' unsigned'
                end
              end
              _li do
                _label do
                  _input type: 'checkbox', checked: @script_font,
                  onClick: -> {@script_font = !@script_font}
                  _span ' script font'
                end
              end
            end

            # N.B. The checked: variable names must be reflected in the file incomplete.json.jb

            _label do
              _input type: 'radio', name: 'doctype', value: 'resubmit',
                onClick: self.reject
              _span 'resubmitted form'
            end

            _label do
              _input type: 'radio', name: 'doctype', value: 'empty',
                onClick: self.generic_reject
              _span 'empty form'
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
          _li "\u2704 revert", onMousedown: self.revert
          _li.divider
          _li "\u2716 delete", onMousedown: self.delete_attachment
          _li "\u2709 pdf-ize", onMousedown: self.pdfize
          _li.divider
          _li "parse pdf", onMousedown: self.pdfparse
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
      rescue => _e
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
    window.addEventListener 'popstate' do
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
  def burst(_event)
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
        signature = CheckSignature.find(decodeURIComponent(@selected), response.attachments)
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

  # revert to the original
  def revert(_event)
    data = {
      selected: @menu || decodeURI(@selected),
      message: window.parent.location.pathname
    }

    @busy = true
    HTTP.post('../../actions/revert', data).then {|response|
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
  def pdfize(_event)
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

  # parse pdf and display extracted data
  def pdfparse(_event)
    message = window.parent.location.pathname
    attachment = @menu || decodeURI(@selected)
    url = message.sub('/workbench/','/icla-parse/') + attachment
    window.parent.frames.content.location.href = url
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

  # Note: the doctype value is passed across as @doctype
  def generic_reject(event)
    form = jQuery(event.target).closest('form')
    form.attr('action', "../../tasklist/generic_reject")
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
    return if %w(INPUT TEXTAREA).includes? document.activeElement.nodeName

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
  def dragEnd(_event)
    @drag = nil
  end

  # implement content navigation using the history API
  def navigate(event)
    destination = event.target.attributes['href'].value
    window.parent.frames.content.history.replaceState({}, nil, destination)
  end
end
