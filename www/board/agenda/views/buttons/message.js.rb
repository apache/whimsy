#
# Message area for backchannel
#
class Message < Vue
  def initialize
    @disabled = false
    @message = ''
  end

  # render an input area in the button area (a very w-i-d-e button)
  def render
    _form onSubmit: self.sendMessage do
      _input.chatMessage! value: @message
    end
  end

  # autofocus on the chat message when the page is initially displayed
  def mounted()
    document.getElementById("chatMessage").focus()
  end

  # send message to server
  def sendMessage(event)
    event.stopPropagation()
    event.preventDefault()

    if @message
      post 'message', agenda: Agenda.file, text: @message do |message|
        Chat.add message
        @message = ''
      end
    end

    return false
  end
end
