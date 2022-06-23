#
# Index page showing unprocessed messages with attachments
#

class Index < Vue
  def log(msg)
    console.log msg
  end

  def initialize()
    log 'initialize'
    @selected = nil
    @messages = []
    @checking = false
    @fetched = false
  end

  # crop a value before display
  def _crop(text, max)
    if text and text.length > max
      return text[0..max] + ' ...'
    end
    return text
  end

  def render()
    log 'render'
    if not @messages or @messages.all? {|message| message.status == :deleted}
      _p.container_fluid 'All documents have been processed.'
    else
      _table.table do
        _thead do
          _tr do
            _th 'Date'
            _th 'From'
            _th 'Subject'
          end
        end

        _tbody do
          @messages.each do |message|

            # determine the 'color' to use for the row
            color = nil
            color = 'deleted' if message.status == :deletePending
            color = 'hidden' if message.status == :deleted
            color = 'selected' if message.href == @selected

            row_options = {
              :class => color,
              on: {click: self.selectRow, doubleClick: self.nav}
            }

            _tr row_options do
              _td do
                if %i[emeritusReady emeritusPending].include? message.status
                  _a message.date, href: message.href, title: message.time, target: "_blank"
                else
                  _a message.date, href: message.href, title: message.time
                end
              end
              _td _crop(message.from, 40)
              if %i[emeritusReady emeritusPending].include? message.status
                _td do
                  _a message.subject, class: message.status, href: message.href2, target: "_blank"
                end
              elsif message.secmail
                _td do
                  _ message.subject
                  _ ' - '
                  _b message.secmail.inspect # TODO better presentation of content
                end
              else
                _td _crop(message.subject, 60)
              end
            end
          end
        end
      end
    end

    if @fetched and @nextmbox
      _button.btn.btn_primary 'download previous month',
        onClick: self.fetch_month
    end

    if defined? window
      unless window.location.hostname =~ /^whimsy.*\.apache\.org$/
        _button.btn.btn_success 'check for new mail', onClick: self.refresh,
          disabled: @checking
      end
    end

    unless Status.undoStack.empty?
      _button.btn.btn_info 'undo delete', onClick: self.undo
    end
  end

  # initialize next mailbox (year+month)
  def beforeMount()
    @nextmbox = @@mbox
    if @@messages
      log 'beforeMount - messages'
    else
      log 'beforeMount - nomessages'
    end
    self.mergemsgs @@messages if @@messages
    # temp debug
    self.merge @@messages if @@messages
    merge @@messages if @@messages
  end

  # on initial load, fetch latest mailbox, subscribe to keyboard and
  # server side events, and initialize selected item.
  def mounted()
    today = Date.new()
    twice = (today.getMonth()+1==@nextmbox[4..5].to_i and today.getDate()<=7)
    log "mounted twice=#{twice} next=#{@nextmbox}"
    self.fetch_month() do
      if @nextmbox and twice
        # for the first week of the month, fetch previous month too
        self.fetch_month() do
          @fetched = true
        end
      else
        @fetched = true
      end
    end

    window.onkeydown = self.keydown

    # when events are received, update messages
    events = EventSource.new('events')
    events.addEventListener :message do |event|
      messages = JSON.parse(event.data).messages
      self.mergemsgs messages if messages
    end

    # close connection on exit
    window.addEventListener :unload do |event|
      events.close()
    end

    # select row
    self.selectRow Status.selected if @messages.length > 0
  end

  # when content changes, ensure selected message is visible
  def updated()
    log 'updated'
    if @selected
      selected = document.querySelector("a[href='#{@selected}']")
      if selected
        rect = selected.getBoundingClientRect()
        if
          rect.top < 0 or rect.left < 0 or
          rect.bottom > window.innerHeight or rect.right > window.innerWidth
        then
          selected.scrollIntoView()
        end
      end
    end
  end

  # fetch a month's worth of messages
  def fetch_month(&block)
    log "fetch_month #{@nextmbox}"
    HTTP.get(@nextmbox, :json).then {|response|
      # update latest mbox
      @nextmbox = response.mbox

      # add messages to list
      self.mergemsgs response.messages

      # select oldest message
      self.selectRow Status.selected || @messages.last unless @selected

      # if block provided, call it
      block() if block and block.is_a? Function
    }.catch {|error|
      console.log error
      alert error
    }
  end

  def merge(messages)
    log 'merge()'
  end

  # merge new messages into the list
  def mergemsgs(messages)
    log "mergemsgs #{messages.length}"
    messages.each do |new_message|
      index = @messages.find_index do |old_message|
        old_message.time < new_message.time or
        (old_message.time == new_message.time and
         old_message.href <= new_message.href)
      end

      if index == -1
        @messages << new_message
      elsif @messages[index].href == new_message.href
        @messages[index] = new_message
      else
        @messages.splice index, 0, new_message
      end
    end

    Vue.forceUpdate() unless messages.empty?
  end

  # update @selected, given either a DOM event or a message
  def selectRow(object)
    if not object
      href = nil
    elsif typeof(object) == 'string'
      href = object
    elsif object.respond_to? :currentTarget
      href = object.currentTarget.querySelector('a').getAttribute('href')
    elsif object.respond_to? :href
      href = object.href
    else
      href = object
    end

    # ensure selected message is not deleted
    index = @messages.find_index {|m| m.href == href}
    index -= 1 while index >= 0 and @messages[index].status == :deleted
    index = @messages.find_index {|m| m.status != :deleted} if index == -1

    @selected = Status.selected = (index >= 0 ? @messages[index].href : nil)
  end

  # navigate
  def nav(event)
    self.selectRow(event)
    window.location.href = @selected
    window.getSelection().removeAllRanges()
    event.preventDefault()
  end

  def undo(event)
    message = Status.popStack()
    selected = @messages.find {|m| m.href == message}
    if selected
      self.selectRow selected
      selected.status = :deletePending

      # send request to server to remove delete status
      HTTP.patch(selected.href, status: nil).then {
        delete selected.status
        Vue.forceUpdate()
        self.selectRow message
      }.catch {|error|
        alert error
      }
    end
  end

  def refresh(event)
    log "refresh #{@@mbox}"
    @checking = true
    HTTP.post("actions/check-mail", mbox: @@mbox).then {|response|
      self.mergemsgs response.messages
      @checking = false
    }.catch {|error|
      alert error
      @checking = false
    }
  end

  # handle keyboard events
  def keydown(event)
    if event.keyCode == 38 # up
      index = @messages.find_index {|m| m.href == @selected}
      self.selectRow @messages[index-1] if index > 0
      event.preventDefault()

    elsif event.keyCode == 40 # down
      index = @messages.find_index {|m| m.href == @selected} + 1
      while index < @messages.length and @messages[index].status == :deleted
        index += 1
      end
      self.selectRow @messages[index] if index < @messages.length
      event.preventDefault()

    elsif event.keyCode == 13 or event.keyCode == 39 # enter/return or right
      selected = @messages.find {|m| m.href == @selected}
      window.location.href = selected.href if selected

    elsif event.keyCode == 8 or event.keyCode == 46 # backspace or delete
      if event.metaKey or event.ctrlKey
        event.preventDefault()

        # mark item as delete pending
        selected = @selected
        index = @messages.find_index {|m| m.href == selected}
        @messages[index].status = :deletePending if index >= 0

        # move selected pointer
        if index > 0
          self.selectRow @messages[index-1]
        elsif index < @messages.length - 1
          self.selectRow @messages[index+1]
        else
          self.selectRow nil
        end

        # send request to server to perform delete
        HTTP.delete(selected).then {
          index = @messages.find_index {|m| m.href == selected}
          @messages[index].status = :deleted if index >= 0
          Status.pushDeleted selected
          self.selectRow selected if @selected == selected
          Vue.forceUpdate()
        }.catch {|error|
          alert error
        }
      end

    elsif event.keyCode == 'Z'.ord
      if event.ctrlKey or event.metaKey
        unless Status.undoStack.empty?
          self.undo()
          event.preventDefault()
        end
      end
    else
      console.log "keydown: #{event.keyCode}"
    end
  end
end
