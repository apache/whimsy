#
# A button that will toggle offline status
#
class Offline < Vue
  def render
    if Server.offline
      _button.btn.btn_primary 'go online', onClick: click
    else
      _button.btn.btn_primary 'go offline', onClick: click
    end
  end

  def click(event)
    Pending.setOffline(!Server.offline)
  end
end
