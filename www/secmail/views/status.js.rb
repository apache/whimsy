#
# Encapsulate memory of selected item and delete stack
#

class Status
  def self.secmail
    return {} if not defined? sessionStorage
    JSON.parse(sessionStorage.getItem('secmail') || '{}')
  end

  def self.selected
    Status.secmail.selected
  end

  def self.selected=(value)
    secmail = Status.secmail
    secmail.selected=value
    sessionStorage.setItem('secmail', JSON.stringify(secmail))
  end

  def self.undoStack
    secmail = Status.secmail
    return secmail.undoStack || []
  end

  def self.pushDeleted(value)
    value = value[/\w+\/\w+\/?$/].sub(/\/?$/, '/')
    secmail = Status.secmail
    secmail.undoStack ||= []
    secmail.undoStack << value
    sessionStorage.setItem('secmail', JSON.stringify(secmail))
  end

  def self.popStack()
    secmail = Status.secmail
    secmail.undoStack ||= []
    item = secmail.undoStack.pop()
    sessionStorage.setItem('secmail', JSON.stringify(secmail))
    return item
  end
end
