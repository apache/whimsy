#
# This component handles both add and edit comment actions.  The save
# button is disabled until the comment is changed.  A delete button is
# provided to clear the comment if it isn't already empty.
#
# When the save button is pushed, a POST request is sent to the server.
# When a response is received, the pending status is updated and the
# form is dismissed.
#

class AddComment < Vue
  def initialize
    @base = @comment = @@item.pending
    @disabled = false
    @checked = @@item.flagged
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'add comment',
      class: 'btn_primary',
      data_toggle: 'modal',
      data_target: '#comment-form'
    }
  end

  def render
    _ModalDialog.comment_form! color: 'commented' do
      # header
      if @base
        _h4 'Edit comment'
      else
        _h4 'Enter a comment'
      end

      #input field: initials
      _input.comment_initials! label: 'Initials',
        placeholder: 'initials', disabled: @disabled,
        value: @@server.pending.initials || @@server.initials

      #input field: comment text
      _textarea.comment_text!  value: @comment, label: 'Comment',
        placeholder: 'comment', rows: 5, disabled: @disabled

      if Server.role == :director and @@item.attach =~ /^[A-Z]+$/
        _input.flag! type: 'checkbox', label: 'item requires discussion or follow up',
          onChange: self.flag, checked: @checked
      end

      # footer buttons
      _button.btn_default 'Cancel', data_dismiss: 'modal',
        disabled: @disabled

      if @comment
        _button.btn_warning 'Delete', onClick: self.delete, disabled: @disabled
      end

      _button.btn_primary 'Save', onClick: self.save,
        disabled: @disabled || @comment == @base
    end
  end

  # autofocus on comment text
  def mounted()
    jQuery('#comment-form').on 'shown.bs.modal' do
      document.getElementById("comment-text").focus()
    end
  end

  # when delete button is pushed, clear the comment
  def delete(event)
    @comment = ''
  end

  # when save button is pushed, post comment and dismiss modal when complete
  def save(event)
    Server.initials = document.getElementById("comment-initials").value

    data = {
      agenda: Agenda.file,
      attach: @@item.attach,
      initials: Server.initials,
      comment: @comment
    }

    @disabled = true
    post 'comment', data do |pending|
      jQuery('#comment-form').modal(:hide)
      document.body.classList.remove('modal-open')
      @disabled = false
      Pending.load pending
    end
  end

  def flag(event)
    @checked = ! @checked

    data = {
      agenda: Agenda.file,
      initials: Server.initials,
      attach: @@item.attach,
      request: (event.target.checked ? 'flag' : 'unflag')
    }

    post 'approve', data do |pending|
      Pending.load pending
    end
  end
end
