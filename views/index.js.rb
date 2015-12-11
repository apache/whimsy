#
# Index page showing unprocessed messages with attachments
#

class Index < React
  def initialize
    @selected = nil
    @messages = []
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
          _tr class: ('selected' if message.href == @selected) do
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
      onClick: self.fetch
  end

  # initialize latest mailbox (year+month)
  def componentWillMount()
    @latest = @@mbox
  end

  # on initial load, fetch latest mailbox and subscribe to keyboard events
  def componentDidMount()
    self.fetch()
    window.onkeydown = self.keydown
  end

  # when content changes, scroll to selected message
  def componentDidUpdate()
    if @selected
      selected = document.querySelector("a[href='#{@selected}']")
      selected.scrollIntoView() if selected
    end
  end

  # fetch a month's worth of messages
  def fetch()
    # build JSON post XMLHttpRequest
    xhr = XMLHttpRequest.new()
    xhr.open 'POST', "", true
    xhr.setRequestHeader 'Content-Type', 'application/json;charset=utf-8'
    xhr.responseType = 'json'

    # process response
    def xhr.onreadystatechange()
      if xhr.readyState == 4
        response = xhr.response.json

        # update latest mbox
        @latest = response.mbox if response.mbox

        # add messages to list
        @messages = @messages.concat(*response.messages)

        # select oldest message
        @selected = @messages.last.href
      end
    end

    xhr.send(JSON.stringify mbox: @latest)
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
    else
      alert event.keyCode
    end
  end
end
