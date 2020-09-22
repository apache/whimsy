#
# Commit pending comments and approvals.  Build a default commit message,
# and allow it to be changed.
#

class Commit < Vue
  def initialize
    @disabled = false
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'commit',
      class: 'btn_primary',
      disabled: Server.offline || Minutes.complete || Minutes.draft_posted,
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

  # autofocus on comment text
  def mounted()
    jQuery('#commit-form').on 'shown.bs.modal' do
      document.getElementById("commit-text").focus()
    end
  end

  # update message on re-display
  def created()
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

  # on click, disable the input fields and buttons and submit
  def click(event)
    @disabled = true
    post 'commit', message: @message, initials: User.initials do |response|
      Agenda.load response.agenda, response.digest
      Pending.load response.pending
      @disabled = false

      # delay jQuery updates to give Vue a chance to make updates first
      setTimeout 300 do
        jQuery('#commit-form').modal(:hide)
        document.body.classList.remove('modal-open')
        jQuery('.modal-backdrop').remove();
      end
    end
  end
end
