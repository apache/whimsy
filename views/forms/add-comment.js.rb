class AddComment < React
  def initialize
    @save_disabled = true
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
      _h4 'Enter a comment'

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
        _textarea.comment_text!.form_control label: 'Comment',
          placeholder: 'comment', rows: 5, onInput: self.input
      end

      # footer buttons
      _button.btn_default 'Cancel', data_dismiss: 'modal'
      _button.btn_primary 'Save', disabled: @save_disabled, onClick: self.save
    end
  end

  # autofocus on comment form
  def componentDidMount()
    jQuery('#comment-form').on 'shown.bs.modal' do
      ~'#comment-text'.focus()
    end
  end

  # enable/disable save when input changes
  def input(event)
    @save_disabled = ( event.target.value.length == 0 )
  end

  def save(event)
    data = {
      agenda: Agenda.file,
      attach: @@item.attach,
      initials: ~'#comment_initials'.value,
      comment: ~'#comment_text'.value
    }

    post 'comment', data do |pending|
      Pending.load pending
      jQuery('#comment-form').modal(:hide)
    end
  end
end
