#
# A button that will toggle offline status
#
class Offline < Vue
  def initialize
    @disabled = false
  end

  def render
    if Server.offline
      _button.btn.btn_primary 'go online', onClick: click, disabled: @disabled
    else
      _button.btn.btn_primary 'go offline', onClick: click, disabled: @disabled
    end
  end

  def click(event)
    if Server.offline
      @disabled = true

      Pending.dbget do |pending|
        # construct arguments to fetch
        args = {
          method: 'post',
          credentials: 'include',
          headers: {'Content-Type' => 'application/json'},
          body: {agenda: Agenda.file, pending: pending}.inspect
        }

        fetch('../json/batch', args).then {|response|
          if response.ok
            Pending.dbput({})
            response.json().then do |pending|
              Server.pending = pending
            end
            Pending.setOffline(false)
          else
            response.text().then do |text|
              alert("Server error: #{response.status}")
              console.log text
            end
          end

          @disabled = false
        }.catch {|error|
          alert(error)
          @disabled = false
        }
      end
    else
      Pending.setOffline(true)
    end
  end
end
