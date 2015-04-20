#
# Main class, nearly all scaffolding for demo purposes
#

class Main < React
  def initialize
    @view = Invite
  end

  def render
    _main do
      _h1 'Demo Online ICLA Form'

      React.createElement(@view)
    end
  end

  # save data on first load
  def componentWillMount()
    Server.data = @@data
    self.componentWillReceiveProps()
  end

  # set view based on properties
  def componentWillReceiveProps()
    if @@view == 'interview'
      @view = Interview
    else
      @view = Invite
    end
  end

  # Another navigation means in support of the demo
  def navigate(view)
    @view = view
    window.scrollTo(0, 0)
  end

  # export navigation method on the client
  def componentDidMount()
    Main.navigate = self.navigate
  end
end
