#!/usr/bin/ruby

# define filters used in views to help with formatting

module Angular::AsfBoardDirectives

  # construct full Bootstrap modal dialog from a minimal structure
  directive :modalDialog do
    restrict :E
    replace true

    def template(element, attrs)
      # detach h4 elements and buttons
      h4 = element.find('h4').detach()
      buttons = element.find('button').addClass('btn').detach()

      # build label elements from label attributes, wrap in a form-group
      element.find('*[label]').each! do |index, node|
        ~node.wrap(_div.form_group)
        ~node.before(_label ~node.attr('label'), for: ~node.attr('id'))
      end

      # build bootstrap dialog
      dialog = _div.modal.fade tabindex: -1 do
        _div.modal_dialog do
          _div.modal_content do
            _div.modal_header do
              _button.close "\u00d7", type: 'button', data_dismiss: 'modal'

              # move h4 class attribute to header; replace with 'modal-title'
              ~self.addClass(h4.attr(:class)) if h4.attr(:class)
              ~self.append(h4.attr(class: 'modal-title'))
            end

            _div.modal_body do
              # add form-control attributes; move remaining nodes to the body
              element.find('input, textarea').addClass('form-control')
              ~self.append(element.children())
            end

            _div.modal_footer do
              # move buttons to the footer
              ~self.append(buttons)
            end
          end
        end
      end

      # return dialog as html
      return dialog[0].outerHTML
    end

    def link(scope, element, attr)
      # implement autofocus
      element.on('shown.bs.modal') do
        element.find('*[autofocus]').focus()
      end
    end
  end
end
