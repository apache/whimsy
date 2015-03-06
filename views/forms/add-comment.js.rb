class AddComment < React
  def initialize
    @base = @comment = @@item.pending
  end

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
      _div.form_group do
        _label 'Initials', for: 'comment-initials'
        _input.comment_initials!.form_control label: 'Initials',
          placeholder: 'initials', 
          defaultValue: @@server.pending.initials || @@server.initials
      end

      #input field: comment text
      _div.form_group do
        _label 'Comment', for: 'comment-text'
        _textarea.comment_text!.form_control value: @comment, label: 'Comment',
          placeholder: 'comment', rows: 5, onChange: self.change
      end

      # footer buttons
      _button.btn_default 'Cancel', data_dismiss: 'modal'
      _button.btn_warning 'Delete', onClick: self.delete if @comment
      _button.btn_primary 'Save', onClick: self.save,
        disabled: (@comment == @base)
    end
  end

  # autofocus on comment form
  def componentDidMount()
    jQuery('#comment-form').on 'shown.bs.modal' do
      ~'#comment-text'.focus()
    end
  end

  # update comment when textarea changes, triggering hiding/showing the
  # Delete button and enabling/disabling the Save button.
  def change(event)
    @comment = event.target.value
  end

  # when item changes, reset base and comment
  def componentWillReceiveProps(props)
    if props.item.href != @@item.href
      @base = @comment = props.item.pending || ''
    end
  end

  # when delete button is pushed, clear the comment
  def delete(event)
    @comment = ''
  end

  # when save button is pushed, post comment and dismiss modal when complete
  def save(event)
    data = {
      agenda: Agenda.file,
      attach: @@item.attach,
      initials: ~'#comment_initials'.value,
      comment: @comment
    }

    post 'comment', data do |pending|
      Pending.load pending
      jQuery('#comment-form').modal(:hide)
    end
  end
end
