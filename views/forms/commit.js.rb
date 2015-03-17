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
      _textarea.commit_text! @message, rows: 5, disabled: @disabled,
        label: 'Commit message'

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
  def componentWillReceiveProps(props)
    messages = []

    # list (or number) of reports approved with this commit
    approved = Pending.approved.length
    if approved > 0 and approved < 6
      titles = []
      Agenda.index.each do |item|
        titles << item.title if Pending.approved.include? item.attach
      end
      messages << "Approve #{titles.join(', ')}"
    elsif approved > 1
      messages << "Approve #{approved} reports"
    end

    # list (or number) of comments made with this commit
    comments = Pending.comments.keys().length
    if comments > 0 and comments < 6
      titles = []
      Agenda.index.each do |item|
        titles << item.title if Pending.comments[item.attach]
      end
      messages << "Comment on #{titles.join(', ')}"
    elsif comments > 1
      messages << "Comment on #{comments} reports"
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
    post 'commit', message: @message do |response|
      jQuery('#commit-form').modal(:hide)
      @disabled = false
      Pending.load response.pending
      Agenda.load response.agenda
    end
  end
end
