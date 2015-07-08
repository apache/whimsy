#
# Commit pending comments and approvals.  Build a default commit message,
# and allow it to be changed.
#

class Commit < React
  def initialize
    @disabled = false
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'commit',
      class: 'btn_primary',
      data_toggle: 'modal',
      data_target: '#commit-form'
    }
  end

  # commit form: allow the user to confirm or edit the commit message
  def render
    _ModalDialog.commit_form! color: 'blank' do
      # header
      _h4 'Commit message'

      # single text area input field
      _textarea.commit_text! value: @message, rows: 5, 
        disabled: @disabled, label: 'Commit message'

      # buttons
      _button.btn_default 'Close', data_dismiss: 'modal'
      _button.btn_primary 'Submit', onClick: self.click, disabled: @disabled
    end
  end

  # set message on initial display
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # autofocus on comment text
  def componentDidMount()
    jQuery('#commit-form').on 'shown.bs.modal' do
      ~'#commit-text'.focus()
    end
  end

  # update message on re-display
  def componentWillReceiveProps()
    pending = @@server.pending
    messages = []

    # common format for message lines
    append = proc do |title, list|
      next unless list
      if list.length > 0 and list.length < 6
        titles = []
        Agenda.index.each do |item|
          titles << item.title if list.include? item.attach
        end
        messages << "#{title} #{titles.join(', ')}"
      elsif list.length > 1
        messages << "#{title} #{list.length} reports"
      end
    end

    append 'Approve', pending.approved
    append 'Unapprove', pending.unapproved
    append 'Flag', pending.flagged
    append 'Unflag', pending.unflagged

    # list (or number) of comments made with this commit
    comments = pending.comments.keys().length
    if comments > 0 and comments < 6
      titles = []
      Agenda.index.each do |item|
        titles << item.title if pending.comments[item.attach]
      end
      messages << "Comment on #{titles.join(', ')}"
    elsif comments > 1
      messages << "Comment on #{comments} reports"
    end

    # identify (or number) action item(s) updated with this commit
    if pending.status
      if pending.status.length == 1
        item = pending.status.first
        text = item.text
        if item.pmc or item.date
          text += ' ['
          text += " #{item.pmc}" if item.pmc
          text += " #{item.date}" if item.date
          text += ' ]'
        end

        messages << "Update AI: #{text}"
      elsif pending.status.length > 1
        messages << "Update #{pending.status.length} action items"
      end
    end

    @message = messages.join("\n")
  end

  # update message when textarea changes
  def change(event)
    @message = event.target.value
  end

  # on click, disable the input fields and buttons and submit
  def click(event)
    @disabled = true
    post 'commit', message: @message, initials: Pending.initials do |response|
      jQuery('#commit-form').modal(:hide)
      document.body.classList.remove('modal-open')
      Agenda.load response.agenda
      Pending.load response.pending
      @disabled = false
    end
  end
end
