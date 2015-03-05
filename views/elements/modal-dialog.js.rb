class ModalDialog < React
  def initialize
    @header = []
    @body = []
    @footer = []
  end

  def componentWillMount()
    self.componentWillReceiveProps(self.props)
  end

  def componentWillReceiveProps(props)
    @header.clear()
    @body.clear()
    @footer.clear()

    props.children.each do |child|
      if child.type == 'h4'
        if not child.props.className
          child.props.className = 'modal-title'
        elsif not child.props.className.split(' ').include? 'modal-title'
          child.props.className += ' modal-title'
        end

        @header << child
        ModalDialog.h4 = child

      elsif child.type == 'button'
        if not child.props.className
          child.props.className = 'btn'
        elsif not child.props.className.split(' ').include? 'btn'
          child.props.className += ' btn'
        end

        @footer << child

      else
        @body << child
      end
    end
  end

  def render
    _div.modal.fade id: @@id, class: @@className do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header class: @@color do
            _button.close "\u00d7", type: 'button', data_dismiss: 'modal'
            _[*@header]
          end

          _div.modal_body do
            _[*@body]
          end

          _div.modal_footer class: @@color do
            _[*@footer]
          end
        end
      end
    end
  end
end
