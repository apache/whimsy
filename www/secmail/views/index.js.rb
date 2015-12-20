#
# Index page showing unprocessed messages with attachments
#

class Index < React
  def initialize
    @selected = nil
    @messages = []
    @checking = false
  end

  def render
    _table do
      _thead do
        _tr do
          _th 'Timestamp'
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

          _tr class: color, onClick: self.selectRow, onDoubleClick: self.nav do
            _td do
              _a message.time, href: "#{message.href}"
            end 
            _td message.from
            _td message.subject
          end
        end
      end
    end

    if @nextmbox
      _button.btn.btn_primary 'download previous month',
        onClick: self.fetch_month
    end

    _button.btn.btn_success 'check for new mail', onClick: self.refresh,
      disabled: @checking

    unless Status.undoStack.empty?
      _button.btn.btn_info 'undo delete', onClick: self.undo
    end
  end

  # initialize next mailbox (year+month)
  def componentWillMount()
    @nextmbox = @@mbox
  end

  # on initial load, fetch latest mailbox and subscribe to keyboard events,
  # initialize selected item.
  def componentDidMount()
    self.fetch_month()
    window.onkeydown = self.keydown
     self.selectRow Status.selected if @messages.length > 0
  end

  # when content changes, ensure selected message is visible
  def componentDidUpdate()
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
  def fetch_month()
    HTTP.get("/#{@nextmbox}", :json) do |response|
      # update latest mbox
      @nextmbox = response.mbox

      # add messages to list
      @messages = @messages.concat(*response.messages)

      # select oldest message
      self.selectRow Status.selected || @messages.last unless @selected
    end
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
    index = @messages.findIndex {|m| return m.href == href}
    index -= 1 while index >= 0 and @messages[index].status == :deleted
    index = @messages.findIndex {|m| return m.status != :deleted} if index == -1

    @selected = Status.selected = @messages[index].href
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
    selected = @messages.find {|m| return m.href == message}
    if selected
      self.selectRow selected
      selected.status = :deletePending

      # send request to server to remove delete status
      HTTP.patch(selected.href, status: nil) do
        delete selected.status
        self.forceUpdate()
        self.selectRow message
      end
    end
  end

  def refresh(event)
    @checking = true
    HTTP.post "actions/check-mail", mbox: @@mbox do |response|
      location.reload()
    end
  end

  # handle keyboard events
  def keydown(event)
    if event.keyCode == 38 # up
      index = @messages.findIndex {|m| return m.href == @selected}
      self.selectRow @messages[index-1] if index > 0
      event.preventDefault()

    elsif event.keyCode == 40 # down
      index = @messages.findIndex {|m| return m.href == @selected} + 1
      while index < @messages.length and @messages[index].status == :deleted
        index += 1
      end
      self.selectRow @messages[index] if index < @messages.length
      event.preventDefault()

    elsif event.keyCode == 13 or event.keyCode == 39 # enter/return or right
      selected = @messages.find {|m| return m.href == @selected}
      window.location.href = selected.href if selected

    elsif event.keyCode == 8 or event.keyCode == 46 # backspace or delete
      if event.metaKey
        event.preventDefault()

        # mark item as delete pending
        selected = @selected
        index = @messages.findIndex {|m| return m.href == selected}
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
        HTTP.delete(selected) do
          index = @messages.findIndex {|m| return m.href == selected}
          @messages[index].status = :deleted if index >= 0
          Status.pushDeleted selected
          self.selectRow selected if @selected == selected
          self.forceUpdate()
        end
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
