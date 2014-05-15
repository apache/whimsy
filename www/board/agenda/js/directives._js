#!/usr/bin/ruby

# define filters used in views to help with formatting

module Angular::AsfBoardDirectives
  # dynamically resize main to leave room for header and footer
  directive :main do
    restrict :E
    def link(scope, element, attr)
      watch ~'header.navbar'.css(:height) do |value|
        element.css(marginTop: value)
      end

      watch ~'footer.navbar'.css(:height) do |value|
        element.css(marginBottom: value)
      end
    end
  end

  # link traversal via left/right keys
  directive :body do
    restrict :E
    def link(scope, element, attr)
      element.find('*[autofocus]').focus()

      element.keydown do |event|
        return unless ~('.modal-open').empty? and ~('#search-text').empty?
        return if event.metaKey or event.ctrlKey

        if event.keyCode == 37 # '<-'
          ~"a[rel='prev']".click
          return false
        elsif event.keyCode == 39 # '->'
          ~"a[rel='next']".click
          return false
        elsif event.keyCode == 'C'.ord
          ~"#comments"[0].scrollIntoView()
          return false
        elsif event.keyCode == 'I'.ord
          ~"#info".click
          return false
        elsif event.keyCode == 'N'.ord
          ~"#nav".click
          return false
        elsif event.keyCode == 'A'.ord
          ~"#agenda".click
          return false
        elsif event.keyCode == 'Q'.ord
          ~"#queue".click
          return false
        elsif event.keyCode == 'S'.ord
          ~"#shepherd".click
          return false
        elsif event.shiftKey and event.keyCode == 191 # "?"
          ~"#help".click
          return false
        elsif event.keyCode == 'R'.ord
          ~'#clock'.show
          Pending.get()
          data = {agenda: Data.get('agenda')}
          $http.post('../json/refresh', data).success do |response|
            Agenda.put response
            $route.reload()
            ~'#clock'.hide
          end
          return false
        end
      end
    end
  end

  # construct full Bootstrap modal dialog from a minimal structure
  directive :modalDialog do
    restrict :E
    replace true

    def template(element, attrs)
      # detach h4 elements and buttons
      h4 = element.find('h4').detach()
      buttons = element.children('button').addClass('btn').detach()

      # add form-control attributes
      element.children('input, textarea').addClass('form-control')

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
              ~this.addClass(h4.attr(:class)) if h4.attr(:class)
              ~this.append(h4.attr(class: 'modal-title'))
            end

            _div.modal_body do
              # move remaining nodes to the body
              ~this.append(element.children())
            end

            _div.modal_footer do
              # move buttons to the footer
              ~this.append(buttons)
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
