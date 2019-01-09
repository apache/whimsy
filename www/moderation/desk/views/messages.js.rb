#
# List page showing messages
#

class Messages < Vue
  def initialize
    console.log "initialise"
    @selected = nil
    @messages = []
    @checking = false
    @fetched = false
    @nextmbox = nil
  end

  def render
    console.log "render"
    if not @messages
      _p.container_fluid 'All documents have been processed.'
    else
      _p "Count: #{@messages.length}"

      # The name values must agree with action scripts such as email.json.rb
      _button.btn.btn_info 'Accept and Allow', onClick: self.mark, name: ACCEPTALLOW, disabled: !@selected
      _button.btn.btn_info 'Accept only',      onClick: self.mark, name: ACCEPT, disabled: !@selected
      _button.btn.btn_info 'Reject',           onClick: self.mark, name: REJECT, disabled: !@selected
      _button.btn.btn_info 'This is Spam',     onClick: self.mark, name: MARKSPAM, disabled: !@selected
      _button.btn.btn_info 'Unmark Spam',      onClick: self.undo, disabled: Status.undoStack.empty?
      # TODO accept subscription request - or just re-use Accept?
      # COuld use Reject as well to tell the user why not accepting the request
      # Also want to be able to ignore/delete the request

      _table.table do

        _tbody do
          @messages.each do |message|

            # determine the 'color' to use for the row
            color = nil
            color = 'deleted' if message.status == :deletePending
            color = 'hidden' if message.status == :deleted # should be temporary until next response
            color = 'selected' if message.href == @selected

            row_options = {
              :class => color,
              on: {click: self.selectRow, doubleClick: self.nav}
            }

            _tr row_options do
              _td :id => message.href do # Id needed for mouse selection
                _a message.subject, href: "#{message.href}_body_", target: 'content'
#                _ message.subject
                _br
                _ message.from
                _br
                _a message.return_path, href: "#{message.href}_headers_", target: 'content'
#                _ message.return_path
              end
              _td do
                _ "#{message.list}@#{message.domain}"
                _br
                _ Date.new(message.timestamp*1000.to_i).toISOString() if message.timestamp
                # href must == message.href otherwise selection does not work
                # Note: frame has URL of href
                # target must agree with name in main.html.rb
                _br
                _a message.href, href: "#{message.href}_raw_", target: 'content'
              end 
            end
          end
        end
      end
    end

    unless Status.undoStack.empty?
      _button.btn.btn_info 'undo delete', onClick: self.undo
    end
  end

  # initialize; store passed messages
  def beforeMount()
    Status.emptyStack()
    @nextmbox = @@messages.nextmbox if @@messages
    self.merge @@messages if @@messages
    console.log "beforeMount next #{@nextmbox}"
  end

  def fetch_mbox(&block)
    console.log "fetch_mbox> #{@nextmbox}"
    HTTP.get(@nextmbox, :json).then {|response|
      @nextmbox = response.nextmbox

      # add messages to list
      self.merge response

      # if block provided, call it
      block() if block and block.is_a? Function
    }.catch {|error|
      console.log error
      alert error
    }
    console.log "fetch_mbox< #{@nextmbox}"
  end

  def handle_response()
    console.log "handle_response next #{@nextmbox} max #{@max_fetch}"
    @max_fetch -= 1
    if @nextmbox and @max_fetch > 0
      fetch_mbox() do handle_response() end
    else 
      # select oldest message
      self.selectRow Status.selected || @messages.first
    end
  end

  # on initial load, subscribe to keyboard and
  # server side events, and initialize selected item.
  def mounted()
    console.log "mounted next #{@nextmbox}"
    @max_fetch = 15 # prevent excess fetches
    fetch_mbox() do handle_response() end if @nextmbox

    window.onkeydown = self.keydown

    # when events are received, update messages
    events = EventSource.new('events')
    events.addEventListener :message do |event|
      messages = JSON.parse(event.data).messages
      if messages
        console.log "Message event, source: #{messages.source} count: #{messages.headers.length}"
      else
        console.log event
      end
      self.merge messages if messages
    end

    # close connection on exit
    window.addEventListener :unload do |event|
      events.close()
    end

    # select row
    console.log "mounted selected #{Status.selected}"
    self.selectRow Status.selected if @messages.length > 0
  end

  # when content changes, ensure selected message is visible
  def updated()
    if @selected
      selected = document.querySelector("td[id='#{@selected}']")
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

  # merge new messages into the list
  def merge(messages)
    source = messages.source
    headers = messages.headers
    console.log "merge: " + source + " Count: " + headers.length
    # Drop all entries from the same source file
    temp = @messages.select { |k| not k.href.start_with? source+"/"}
    headers.each do |hdr|
      hdr[:href] = source + "/" + hdr[:id] + "/" # construct the href
      hdr[:id].delete # no longer needed
      # Where to insert the new message (ascending order - oldest first as they may expire)
      index = temp.find_index do |old| 
        old.timestamp > hdr.timestamp
      end
      if index == -1 # not found, i.e. new time is > all entries, so add at end
        temp << hdr
      else # found a newer entry at index, want to insert ahead of it
        temp.splice index, 0, hdr
      end
    end
    @messages = temp
    Vue.forceUpdate() unless messages.empty?
  end

  # update @selected, given either a DOM event or a message
  def selectRow(object)
    hasLink = nil # did we click a link?
#    console.log "SelectRow #{object} #{typeof(object)}"
    if not object
#      console.log "A"
      href = nil
    elsif typeof(object) == 'string'
#      console.log "B"
      href = object
    elsif object.respond_to? :currentTarget
#      console.log "C #{object.srcElement.href}"
      hasLink = object.srcElement.href
      href = object.currentTarget.querySelector('td').getAttribute('id')
    elsif object.respond_to? :href
#      console.log "D"
      href = object.href
    else
#      console.log "E"
      href = object
    end

    # ensure selected message is not deleted
    index = @messages.find_index {|m| m.href == href}
    index -= 1 while index >= 0 and @messages[index].status == :deleted
    # else find first non-deleted entry
    index = @messages.find_index {|m| m.status != :deleted} if index == -1

    previous = @selected
    @selected = Status.selected = (index >= 0 ? @messages[index].href : nil)
#    console.log "SelectRow href #{href} index #{index} previous #{previous} selected #{@selected} S.s #{Status.selected}"
    if @selected # display the message details
      # don't try to display if we have just clicked a link
      parent.content.location=@selected unless hasLink
    else
#      parent.message.document.body.textContent='' TODO
    end
  end

  # navigate
  def nav(event)
    self.selectRow(event)
    window.location.href = @selected
    window.getSelection().removeAllRanges()
    event.preventDefault()
  end

  def send_email(data, &block)
    console.log "send_email > #{data.inspect}"
    HTTP.post('actions/email', data).then {|response|
      console.log "send_email < #{response.inspect}"
      alert response[:mail]
      block() if block
    }.catch {|error|
      alert error
    }
  end

  def mark(event)
    name=event.srcElement.name
    selected = @selected
    if selected
      event.preventDefault()
      # mark item as delete pending
      index = @messages.find_index {|m| m.href == selected}
      @messages[index].status = :deleted if index >= 0
      # move selected pointer to next message
      if index >= 0 and index < @messages.length - 1
        self.selectRow @messages[index+1]
      elsif index > 0 and index == @messages.length - 1
        self.selectRow @messages[index-1]
      else
        self.selectRow nil
      end

      unless name == MARKSPAM
        send_email({id: selected, action: name}) {
          alert "Now patch"
        }
      else
        # TEMP don't delete
        HTTP.patch(selected, status: name).then {
          @messages[index].status = :deleted if index >= 0
          Status.pushDeleted selected if name == MARKSPAM
          self.selectRow @selected # selected above
          Vue.forceUpdate()
        }.catch {|error|
          alert error
        }
      end
    else
      alert "Please select a row"
    end
  end

  def undo(event)
    message = Status.popStack()
    selected = @messages.find {|m| m.href == message}
    if selected
      selected.status = :deletePending
    end
    # send request to server to remove delete status
    HTTP.patch(message, status: nil).then {
      Vue.forceUpdate()
      self.selectRow message
    }.catch {|error|
      alert error
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

    elsif event.keyCode == 'Z'.ord
      if event.ctrlKey or event.metaKey
        unless Status.undoStack.empty?
          self.undo()
          event.preventDefault()
        end
      end
    else
    end
  end
end
