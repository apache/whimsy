#
# Index page showing unprocessed messages with attachments
#

class Index < React
  def initialize
    @selected = nil
    @messages = []
    @undoStack = []
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

    _input.btn.btn_primary type: 'submit', value: 'fetch previous month',
      onClick: self.fetch_month
  end

  # initialize latest mailbox (year+month)
  def componentWillMount()
    @latest = @@mbox
  end

  # on initial load, fetch latest mailbox and subscribe to keyboard events
  def componentDidMount()
    self.fetch_month()
    window.onkeydown = self.keydown
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
    HTTP.post('', mbox: @latest) do |response|
      # update latest mbox
      @latest = response.mbox if response.mbox

      # add messages to list
      @messages = @messages.concat(*response.messages)

      # select oldest message
      @selected = @messages.last.href
    end
  end

  # select
  def selectRow(event)
    @selected = event.currentTarget.querySelector('a').getAttribute('href')
  end

  # navigate
  def nav(event)
    @selected = event.currentTarget.querySelector('a').getAttribute('href')
    window.location.href = @selected
    window.getSelection().removeAllRanges()
    event.preventDefault()
  end

  # handle keyboard events
  def keydown(event)
    if event.keyCode == 38 # up
      index = @messages.findIndex {|m| return m.href == @selected}
      @selected = @messages[index-1].href if index > 0
      event.preventDefault()

    elsif event.keyCode == 40 # down
      index = @messages.findIndex {|m| return m.href == @selected}
      @selected = @messages[index+1].href if index < @messages.length-1
      event.preventDefault()

    elsif event.keyCode == 13 or event.keyCode == 39 # enter/return or right
      selected = @messages.find {|m| return m.href == @selected}
      window.location.href = selected.href if selected

    elsif event.keyCode == 8 # delete
      event.preventDefault()
      # mark item as delete pending
      selected = @selected
      index = @messages.findIndex {|m| return m.href == selected}
      @messages[index].status = :deletePending if index >= 0

      # move selected pointer
      if index > 0
        @selected = @messages[index-1].href
      elsif index < @messages.length - 1
        @selected = @messages[index+1].href
      else
        @selected = nil
      end

      # send request to server to perform delete
      HTTP.delete(selected) do
        index = @messages.findIndex {|m| return m.href == selected}
        console.log index
        @messages[index].status = :deleted if index >= 0
        @undoStack << selected
        self.forceUpdate()
      end

    else
      console.log "keydown: #{event.keyCode}"
    end
  end
end
