#
# Progressive Web Application 'Add to Home Screen' support
#
class Install < Vue
  def render
    _button.btn.btn_primary 'install', onClick: self.click
  end

  def click(event)
    PageCache.installPrompt.prompt();
    PageCache.installPrompt.userChoice.then do |choice|
      console.log "install: #{choice.outcome}"
      PageCache.installPrompt = nil if choice.outcome == 'accepted'
      Main.refresh()
    end
  end
end
