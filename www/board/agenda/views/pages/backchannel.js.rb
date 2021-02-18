#
# Overall Agenda page: simple table with one row for each item in the index
#

class Backchannel < Vue
  # place a message input field in the buttons area
  def self.buttons()
    return [{button: Message}]
  end

  # render a list of messages
  def render
    _header do
      _h1 'Agenda Backchannel'
    end

    # convert date into a localized string
    datefmt = proc do |timestamp|
      return Date.new(timestamp).
        toLocaleDateString({}, month: 'short', day: 'numeric', year: 'numeric')
    end
    if Chat.log.empty?
      if Chat.backlog_fetched
        _em 'No messages found.'
      else
        _em 'Loading messages'
      end
    else
      i = 0

      # group messages by date
      while i < Chat.log.length
        date = datefmt(Chat.log[i].timestamp)
        _h5.chatlog date unless i == 0 and date == datefmt(Date.new().valueOf())

        # group of messages that share the same (local) date
        _dl.chatlog do
          while i < Chat.log.length
            message = Chat.log[i]
            break if date != datefmt(message.timestamp)
            _dt message.user, key: "t#{message.timestamp}", class: message.type,
              title: Date.new(message.timestamp).toLocaleTimeString()
            _dd key: "d#{message.timestamp}", class: message.type do
              if message.link
                _Link text: message.text, href: message.link
              else
                filters = [hotlink, self.mention]
                filters << self.agenda_link if message.type == :agenda
                _Text raw: message.text, filters: filters
              end
            end
            i += 1
          end
        end
      end
    end
  end

  # highlight mentions of my id
  def mention(text)
    return text.gsub(/<.*?>|\b(#{escapeRegExp(User.userid)})\b/) do |match|
      match[0] == '<' ? match : "<span class=mention>#{match}</span>"
    end
  end

  # link agenda pages
  def agenda_link(text)
    Agenda.index.each do |item|
      text.gsub!(item.title) do |match|
        "<a href='#{item.title.gsub(/[\W]/, '-')}'>#{item.title}</a>"
      end
    end

    return text
  end

  # on initial display, fetch backlog
  def mounted()
    Main.scrollTo = -1
    Chat.fetch_backlog()
  end

  # if we are at the bottom of the page, keep it that way
  def beforeUpdate()
    if
      window.pageYOffset + window.innerHeight >=
      document.documentElement.scrollHeight
    then
      Main.scrollTo = -1
    else
      Main.scrollTo = nil
    end
  end
end
