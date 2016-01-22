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
        child = self.addClass(child, 'modal-title')
        @header << child
        ModalDialog.h4 = child

      elsif child.type == 'button'

        # place button elements into the footer, adding a btn class
        child = self.addClass(child, 'btn')
        @footer << child

      elsif child.type == 'input' or child.type == 'textarea'

        # wrap input and textarea elements in a form-control, 
        # add label if present

        child = self.addClass(child, 'form-control')

        label = nil
        if child.props.label and child.props.id
          props = {htmlFor: child.props.id}
          if child.props.type == 'checkbox'
            props.className = 'checkbox'
            label = React.createElement('label', props, child,
              child.props.label)
            child.props.delete 'label'
            child = nil
          else
            label = React.createElement('label', props, child.props.label)
            child = React.cloneElement(child, label: nil)
          end
        end

        @body << React.createElement('div', {className: 'form-group'}, 
          label, child)

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

  # helper method: add a class to an element, returning new element
  def addClass(element, name)
    if not element.props.className
      element = React.cloneElement(element, className: name)
    elsif not element.props.className.split(' ').include? name
      element = React.cloneElement(element, 
        className: element.props.className + " #{name}")
    end

    return element
  end
end
