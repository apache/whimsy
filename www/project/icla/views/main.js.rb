#
# Main class, nearly all scaffolding for demo purposes
#

class Main < Vue
  def initialize
    @view = Invite
  end

  def render
    _main do
      _h1 'Demo: Discuss, Vote, and Invite'

      Vue.createElement(@view)
    end
  end

  # save data on first load
  def created()
    # @@data is set up by app.html.rb
    Server.data = @@data
  end

  def mounted()
    # @@view is set up by app.html.rb
    # set view based on properties
    if @@view == 'interview'
      @view = Interview
    elsif @@view == 'discuss'
      @view = Discuss
    elsif @@view == 'vote'
      @view = Vote
    else
      @view = Invite
    end

    # export navigation method on the client
    Main.navigate = self.navigate
  end

  # Another navigation means in support of the demo
  def navigate(view)
    @view = view
    window.scrollTo(0, 0)
  end
end
