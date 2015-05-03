#
# Overall Agenda page: simple table with one row for each item in the index
#

class Backchannel < React
  # place a message input field in the buttons area
  def self.buttons()
    return [{button: Message}]
  end

  # render a list of messages
  def render
    _header do
      _h1 'Agenda Backchannel'
    end

    _dl.chatlog Server.backchannel do |message|
      _dt message.user
      _dd message.text
    end
  end

  # on initial display, fetch backlog
  def componentDidMount()
    return unless Server.backchannel.empty?

    fetch "chat/#{Agenda.file[/\d[\d_]+/]}", :json do |chat|
      Server.backchannel = Server.backchannel.concat(chat)
      Main.refresh()
    end
  end

  # after update, scroll to the bottom of the page
  def componentDidUpdate()
    window.scrollTo(0, document.body.scrollHeight)
  end
end
