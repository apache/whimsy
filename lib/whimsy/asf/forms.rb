require 'wunderbar'
require 'wunderbar/markdown'

# Define common page features for whimsy tools using bootstrap styles
class Wunderbar::HtmlMarkup

  # Utility function to add icons to form controls
  def _whimsy_forms_iconlink(icon: nil, iconlabel: nil, iconlink: nil)
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
    aria_describedby = "#{name}_help" if helptext
    _div.form_group do
      _label.control_label.col_sm_3 label, for: "#{name}"
      _div.col_sm_9 do
        _div.input_group do
          args = {
            class: 'form-control', name: "#{name}", id: "#{name}",
            type: "#{type}", placeholder: "#{placeholder}",
            aria_describedby: "#{aria_describedby}", required: required, readonly: readonly
          }
          if rows
            args[:rows] = rows
            _textarea! args do
              _! value
            end
          else
            args[:value] = value
            args[:pattern] = "#{pattern}" if pattern
            _input args
          end
          _whimsy_forms_iconlink(icon: icon, iconlabel: iconlabel, iconlink: iconlink)
        end
        if helptext
          _span.help_block id: "#{aria_describedby}" do
            _markdown "#{helptext}"
          end
        end
      end
    end
  end

  # Display an optionlist control within a form
  # @param name required string ID of control's label
  # @param options required ['value'] or {"value" => 'Label for value'} of all selectable values
  # @param values required 'value' or ['value'] or {"value" => 'Label for value'} of all selected values
  # @param placeholder Currently displayed text if passed (not selectable)
  def _whimsy_forms_select(
    name: nil,
    label: 'Select value(s)',
    values: nil,
    options: nil,
    multiple: false,
    required: false,
    readonly: false,
    icon: nil,
    iconlabel: nil,
    iconlink: nil,
    placeholder: nil,
    helptext: nil
    )
    return unless name
    return unless values
    aria_describedby = "#{name}_help" if helptext
    _div.form_group do
      _label.control_label.col_sm_3 label, for: "#{name}"
      _div.col_sm_9 do
        _div.input_group do
          args = {
            name: "#{name}", id: "#{name}", aria_describedby: "#{aria_describedby}", required: required, readonly: readonly
          }
          if multiple
            args['multiple'] = 'true'
          end
          _select.form_control args do
            if ''.eql?(placeholder)
              _option '', value: '', selected: 'selected'
            else
              _option "#{placeholder}", value: '', selected: 'selected', disabled: 'disabled', hidden: 'hidden'
            end
            # Construct selectable list from values (first) then options
            if values.kind_of?(Array)
              values.each do |val|
                _option val, value: val, selected: true
              end
            elsif values.kind_of?(Hash)
              values.each do |val, disp|
                _option disp, value: val, selected: true
              end
            elsif values # Fallback for simple case of single string value
              _option "#{values}", value: "#{values}", selected: true
              values = [values] # Ensure supports .include? for options loop below
            end
            if options.kind_of?(Array)
              options.each do |val|
                _option val, value: val unless values.include?(val)
              end
            elsif options.kind_of?(Hash)
              options.each do |val, disp|
                _option disp, value: val unless values.include?(val)
              end
            end
          end
          _whimsy_forms_iconlink(icon: icon, iconlabel: iconlabel, iconlink: iconlink)
        end
        if helptext
          _span.help_block id: "#{aria_describedby}" do
            _markdown "#{helptext}"
          end
        end
      end
    end
  end

end
