#
# Main class, nearly all scaffolding for demo purposes
#

class Main < Vue
  def initialize
    @view = Invite
  end

  def render
    _main do
      _h1 'Demo: Invitation to Submit ICLA'

      Vue.createElement(@view)
    end
  end

  # save data on first load
  def created()
    Server.data = @@data
  end

  # set view based on properties
  def mounted()
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
  def mounted()
    Main.navigate = self.navigate
  end
end
