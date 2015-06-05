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
          child = React.cloneElement(child, className: 'modal-title')
        elsif not child.props.className.split(' ').include? 'modal-title'
          child = React.cloneElement(child, 
            className: child.props.className + ' modal-title')
        end

        @header << child
        ModalDialog.h4 = child

      elsif child.type == 'button'

        # place button elements into the footer, adding a btn class

        if not child.props.className
          child = React.cloneElement(child, className: 'btn')
        elsif not child.props.className.split(' ').include? 'btn'
          child = React.cloneElement(child, 
            className: child.props.className + ' btn')
        end

        @footer << child

      elsif child.type == 'input' or child.type == 'textarea'

        # wrap input and textarea elements in a form-control, 
        # add label if present

        if not child.props.className
          child = React.cloneElement(child, className: 'form-control')
        elsif not child.props.className.split(' ').include? 'form-control'
          child = React.cloneElement(child, 
            className: child.props.className + ' form-control')
        end

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
            child.props.delete 'label'
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
end
