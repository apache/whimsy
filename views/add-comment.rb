class AddComment < React
  def render
    _button.btn.btn_primary 'add comment', type: 'button', 
      data_toggle: 'modal', data_target: '#comment-form'

    _div.modal.fade.comment_form! do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header.commented do
            _button.close 'x', type: 'button', data_dismiss: 'modal'
            _h4.modal_title 'Enter a comment'
          end
          _div.modal_body do
            _div.form_group do
              _label 'Initials', for: 'comment-initials'
              _input.comment_initials!.form_control label: 'Initials',
                placeholder: 'initials'
            end
            _div.form_group do
              _label 'Comment', for: 'comment-text'
              _textarea.comment_text!.form_control label: 'Comment',
                placeholder: 'comment', rows: 5
            end
          end
          _div.modal_footer do
            _button.btn.btn_default 'Cancel'
          end
        end
      end
    end
  end
end
