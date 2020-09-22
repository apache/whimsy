#
# Bootstrap modal dialogs are great, but they require a lot of boilerplate.
# This component provides the boiler plate so that other form components
# don't have to.  The elements provided by the calling component are
# distributed to header, body, and footer sections.
#

class ModalDialog < Vue
  def collateSlots()
    sections = {header: [], body: [], footer: []}

    $slots.default.each do |slot|
      if slot.tag == 'h4'

        # place h4 elements into the header, adding a modal-title class
        slot = self.addClass(slot, 'modal-title')
        sections.header << slot

      elsif slot.tag == 'button'

        # place button elements into the footer, adding a btn class
        slot = self.addClass(slot, 'btn')
        sections.footer << slot

      elsif slot.tag == 'input' or slot.tag == 'textarea'

        # wrap input and textarea elements in a form-control,
        # add label if present

        slot = self.addClass(slot, 'form-control')

        label = nil
        if slot.data.attrs.label and slot.data.attrs.id
          props = {attrs: {for: slot.data.attrs.id}}
          if slot.data.attrs.type == 'checkbox'
            props.class = ['checkbox']
            label = Vue.createElement('label', props, [slot,
              Vue.createElement('span', slot.data.attrs.label)])
            slot.data.attrs.delete 'label'
            slot = nil
          else
            label = Vue.createElement('label', props, slot.data.attrs.label)
            slot.data.attrs.delete 'label'
          end
        end

        sections.body << Vue.createElement('div', {class: 'form-group'},
          [label, slot])

      else

        # place all other elements into the body

        sections.body << slot
      end
    end

    return sections
  end

  def render
    sections = self.collateSlots()

    _div.modal.fade id: @@id, class: @@className do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header class: @@color do
            _button.close "\u00d7", type: 'button', data_dismiss: 'modal'
            _[*sections.header]
          end

          _div.modal_body do
            _[*sections.body]
          end

          _div.modal_footer class: @@color do
            _[*sections.footer]
          end
        end
      end
    end
  end

  # helper method: add a class to an element, returning new element
  def addClass(element, name)
    element.data ||= {}
    if not element.data.class
      element.data.class = [name]
    elsif not element.data.class.include? name
      element.data.class << name
    end

    return element
  end
end
