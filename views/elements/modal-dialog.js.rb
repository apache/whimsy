#
# Bootstrap modal dialogs are great, but they require a lot of boilerplate.
# This component provides the boiler plate so that other form components
# don't have to.  The elements provided by the calling component are
# distributed to header, body, and footer sections.
#

class ModalDialog < React
  def initialize
    @header = []
    @body = []
    @footer = []
  end

  def componentWillMount()
    self.componentWillReceiveProps()
  end

  def componentWillReceiveProps()
    @header.clear()
    @body.clear()
    @footer.clear()

    @@children.each do |child|
      if child.type == 'h4'

        # place h4 elements into the header, adding a modal-title class

        if not child.props.className
          child.props.className = 'modal-title'
        elsif not child.props.className.split(' ').include? 'modal-title'
          child.props.className += ' modal-title'
        end

        @header << child
        ModalDialog.h4 = child

      elsif child.type == 'button'

        # place button elements into the footer, adding a btn class

        if not child.props.className
          child.props.className = 'btn'
        elsif not child.props.className.split(' ').include? 'btn'
          child.props.className += ' btn'
        end

        @footer << child

      else

        # place all other elements into the body

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
