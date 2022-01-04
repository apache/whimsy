#
# Encapsulate memory of selected item and delete stack
#


STORAGE_NAME = 'modmail'
class Status
  def self.modmail
    return {} if not defined? sessionStorage
    JSON.parse(sessionStorage.getItem(STORAGE_NAME) || '{}')
  end

  def self.undoStack
    modmail = Status.modmail
    return modmail.undoStack || []
  end

  def self.selected
    Status.modmail.selected
  end

  def self.selected=(value)
#    console.log "Status set selected: #{value}"
    modmail = Status.modmail
    modmail.selected=value
    sessionStorage.setItem(STORAGE_NAME, JSON.stringify(modmail))
  end

  def self.pushDeleted(value)
#    console.log "pushDeleted #{value}"
    value = value[/\w+\/\w+\/?$/].sub(/\/?$/, '/')
    modmail = Status.modmail
    modmail.undoStack ||= []
    modmail.undoStack << value
    sessionStorage.setItem(STORAGE_NAME, JSON.stringify(modmail))
  end

  def self.popStack()
    modmail = Status.modmail
    modmail.undoStack ||= []
    item = modmail.undoStack.pop()
    sessionStorage.setItem(STORAGE_NAME, JSON.stringify(modmail))
#    console.log "popStack: #{item}"
    return item
  end

  def self.emptyStack()
    modmail = Status.modmail
    modmail.undoStack = []
    sessionStorage.setItem(STORAGE_NAME, JSON.stringify(modmail))
  end

end
