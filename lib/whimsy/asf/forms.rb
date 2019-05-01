require 'wunderbar'

# Define common page features for whimsy tools using bootstrap styles
class Wunderbar::HtmlMarkup

  # Display a single input control within a form; or if rows, then a textarea
  # @param name required string ID of control's label 
  def _whimsy_forms_input(
    name: nil,
    label: 'Enter string',
    type: 'text',
    rows: nil, # If rows, then is a textarea instead of input
    value: '',
    required: false,
    readonly: false,
    icon: nil,
    iconlabel: nil,
    iconlink: nil,
    placeholder: nil,
    pattern: nil,
    helptext: nil
    )
    return unless name
    tagname = 'input'
    tagname = 'textarea' if rows
    aria_describedby = "#{name}_help" if helptext
    _div.form_group do
      _label.control_label.col_sm_3 label, for: "#{name}"
      _div.col_sm_9 do
        _div.input_group do
          if pattern
            _.tag! tagname, class: 'form-control', name: "#{name}", id: "#{name}",
            type: "#{type}", pattern: "#{pattern}", placeholder: "#{placeholder}", value: value,
            aria_describedby: "#{aria_describedby}", required: required, readonly: readonly
          else
            _.tag! tagname, class: 'form-control', name: "#{name}", id: "#{name}",
            type: "#{type}", placeholder: "#{placeholder}", value: value,
            aria_describedby: "#{aria_describedby}", required: required, readonly: readonly
          end
          if iconlink
            _div.input_group_btn do
              _a.btn.btn_default type: 'button', aria_label: "#{iconlabel}", href: "#{iconlink}", target: 'whimsy_help' do
                _span.glyphicon class: "#{icon}", aria_label: "#{iconlabel}"
              end
            end
          elsif icon
            _span.input_group_addon do
              _span.glyphicon class: "#{icon}", aria_label: "#{iconlabel}"
            end
          end
        end
        if helptext
          _span.help_block id: "#{aria_describedby}" do
            _ "#{helptext}"
          end
        end
      end
    end
  end

  # Display an optionlist control within a form
  # @param name required string ID of control's label 
  def _whimsy_forms_select(
    name: nil,
    label: 'Enter string',
    value: '', # Currently selected value
    valuelabel: '', # Currently selected valuelabel
    options: nil, # ['value'] or {"value" => 'Label for value'} of all selectable values
    multiple: false,
    required: false,
    readonly: false,
    icon: nil,
    iconlabel: nil,
    iconlink: nil,
    placeholder: nil, # Currently displayed text if value is blank (not selectable)
    helptext: nil
    )
    return unless name
    aria_describedby = "#{name}_help" if helptext
    _div.form_group do
      _label.control_label.col_sm_3 label, for: "#{name}"
      _div.col_sm_9 do
        _div.input_group do
          _select.form_control name: "#{name}", id: "#{name}", multiple: "#{multiple}", aria_describedby: "#{aria_describedby}", required: required, readonly: readonly do
            if ''.eql?(value)
              if ''.eql?(placeholder)
                _option '', value: '', selected: 'selected'
              else
                _option "#{placeholder}", value: '', selected: 'selected', disabled: 'disabled', hidden: 'hidden'
              end
            else
              _option ''.eql?(valuelabel) ? "#{value}" : "#{valuelabel}", value: "#{value}", selected: 'selected'
            end
            if options.kind_of?(Array)
              options.each do |opt|
                _option opt, value: opt
              end
            else
              options.each do |val, disp|
                _option disp, value: val
              end
            end
          end
          if iconlink
            _div.input_group_btn do
              _a.btn.btn_default type: 'button', aria_label: "#{iconlabel}", href: "#{iconlink}", target: 'whimsy_help' do
                _span.glyphicon class: "#{icon}", aria_label: "#{iconlabel}"
              end
            end
          elsif icon
            _span.input_group_addon do
              _span.glyphicon class: "#{icon}", aria_label: "#{iconlabel}"
            end
          end
        end
        if helptext
          _span.help_block id: "#{aria_describedby}" do
            _ "#{helptext}"
          end
        end
      end
    end
  end

end
