#!/usr/bin/ruby

# define filters used in views to help with formatting

module Angular::AsfBoardDirectives

  # construct full Bootstrap modal dialog from a minimal structure
  directive :modalDialog do
    restrict :E
    replace true

    def template(element, attrs)
      # build header
      h4 = ~['h4', element]
      header = ~'<div></div>'.append(h4)
      header.prepend("<button class='close' type='button' " +
        "data-dismiss='modal'>\u00D7</button>")
      for i in 0...h4[0].attributes.length
        attr = h4[0].attributes[i]
        header.attr(attr.name, attr.value)
      end
      h4.attr('class', 'modal-title')
      header.addClass('modal-header')

      # build footer
      button = ~['button',element].addClass('btn')
      footer = ~'<div class="modal-footer"></div>'.append(button)

      # build label elements from label attributes, wrap in a form-group
      ~['*[label]', element].each do |index, node|
        label = ~'<label></label>'.attr('for', ~node.attr('id')).
          text(~node.attr('label'))
        wrapper = ~'<div class="form-group"></div>'
        ~node.before(wrapper)
        wrapper.append(~label).append(~node)
      end

      # add form-control attributes, and wrap in a modal-body
      ~['input, textarea', element].addClass('form-control')
      body = ~'<div class="modal-body"></div>'.append(element.children())

      # build modal-dialog
      content = ~'<div class="modal-content"></div>'
      content.prepend(header).append(body).append(footer)
      dialog = ~'<div class="modal-dialog"></div>'.append(content)
      top = ~'<div tabindex="-1" class="modal fade"></div>'.append(dialog)

      return element.append(top).html()
    end

    def link(scope, element, attr)
      # implement autofocus
      element.on('shown.bs.modal') do
        ~['*[autofocus]', element].focus
      end
    end
  end
end
