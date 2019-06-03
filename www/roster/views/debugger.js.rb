#
# Debugging tool shell
#
class Debugger < Vue
  def initialize
    @committer = {}
  end

  def render
    # Display auth status
    if @auth
      _div.alert.alert_success do 
        _ 'Whimsy Debugging: you are authd'
        _ "#{@auth}"
      end
    end

    _h2 "Welcome #{@committer.id}@apache.org"
    _p 'TODO: add actions to allow debugging utility methods'
  end
  
  def created
  end

end
