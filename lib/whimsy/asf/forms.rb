require 'wunderbar'
require 'wunderbar/markdown'

# Define common page features for whimsy tools using bootstrap styles
class Wunderbar::HtmlMarkup

  # Emit a form control based on a hash of options with a type:
  def _whimsy_field_chooser(**args)
    case args[:type]
    when 'subhead'
      _whimsy_forms_subhead label: args[:label]
    when 'text'
      _whimsy_forms_input args
    when 'textarea'
      args[:rows] ||= '3'
      _whimsy_forms_input args
    when 'select'
      _whimsy_forms_select args
    when 'radio', 'checkbox'
      _whimsy_forms_checkradio args
    else
      _div "#{__method__}(#{args[:type]}) TODO: Error condition?"
    end
  end

  # Utility function to add icons after form controls
  def _whimsy_forms_iconlink(**args)
    if args[:iconlink]
      _div.input_group_btn do
        _a.btn.btn_default type: 'button', aria_label: iconlabel, href: args[:iconlink], target: 'whimsy_help' do
          _span.glyphicon class: args[:icon], aria_label: args[:iconlabel]
        end
      end
    elsif args[:icon]
      _span.input_group_addon do
        _span.glyphicon class: args[:icon], aria_label: args[:iconlabel]
      end
    elsif ['radio', 'checkbox'].include?(args[:type])
      # No-op: do not include blank addon for these controls
    else
      _span.input_group_addon # HACK: include blank addon to ensure consistent sizing
    end
  end

  # Utility function for divs around form controls, including help
  # Note: passes :groupclass thru to input-group control for styling
  def _whimsy_control_wrapper(**args)
    _div.form_group do
      _label.control_label.col_sm_3 args[:label], for: args[:name]
      _div.col_sm_9 do
        _div! class: "input-group #{args[:groupclass]}" do
          yield
          _whimsy_forms_iconlink(args)
        end
        if args[:helptext]
          _span.help_block id: args[:aria_describedby] do
            _markdown args[:helptext]
          end
        end
      end
    end
  end

  # Display a subheader separator between sections of a form
  # @param text string to display
  def _whimsy_forms_subhead(label: 'Form Section')
    _div.form_group do
      _label.col_sm_offset_3.col_sm_9.strong.text_left label
    end
  end

  # Display a single input control within a form; or if rows, then a textarea
  # @param name required string ID of control's label/id
  def _whimsy_forms_input(**args)
    return unless args[:name]
    args[:label] ||= 'Enter string'
    args[:type] ||= 'text'
    args[:id] = args[:name]
    args[:aria_describedby] = "#{args[:name]}_help" if args[:helptext]
    _whimsy_control_wrapper(args) do
      args[:class] = 'form-control'
      if args[:rows]
        _textarea! type: args[:type], name: args[:name], id: args[:id], value: args[:value], class: args[:class],
                   aria_describedby: args[:aria_describedby], rows: args[:rows] do
          _! args[:value]
        end
      else
        _input type: args[:type], name: args[:name], id: args[:id], value: args[:value], class: args[:class],
               aria_describedby: args[:aria_describedby]
      end
    end
  end

  # Display an optionlist control within a form
  # @param name required string ID of control's label/id
  # @param options required ['value'] or {"value" => 'Label for value'} of all selectable values
  # @param values 'value' or ['value'] or {"value" => 'Label for value'} of all selected values
  # @param placeholder Currently displayed text if passed (not selectable)
  def _whimsy_forms_select(**args)
    return unless args[:name]
    return unless args[:options]
    args[:label] ||= 'Select value(s)'
    args[:values] ||= []
    args[:id] = args[:name]
    args[:aria_describedby] = "#{args[:name]}_help" if args[:helptext]
    _whimsy_control_wrapper(args) do
      if args[:multiple]
        args[:multiple] = 'true'
      end
      _select.form_control type: args[:type], name: args[:name], id: args[:id], value: args[:value],
                           aria_describedby: args[:aria_describedby], multiple: args[:multiple] do
        if ''.eql?(args[:placeholder])
          _option '', value: '', selected: 'selected'
        else
          _option args[:placeholder], value: '', selected: 'selected', disabled: 'disabled', hidden: 'hidden'
        end
        # Construct selectable list from values (first) then options
        if args[:values].kind_of?(Array)
          args[:values].each do |val|
            _option val, value: val, selected: true
          end
        elsif args[:values].kind_of?(Hash)
          args[:values].each do |val, disp|
            _option disp, value: val, selected: true
          end
        elsif args[:values] # Fallback for simple case of single string value
          _option args[:values], value: args[:values], selected: true
          args[:values] = [args[:values]] # Ensure supports .include? for options loop below
        end
        if args[:options].kind_of?(Array)
          args[:options].each do |val|
            _option val, value: val unless args[:values].include?(val)
          end
        elsif args[:options].kind_of?(Hash)
          args[:options].each do |val, disp|
            _option disp, value: val unless args[:values].include?(val)
          end
        end
      end
    end
  end

  # Display a list of radio or checkbox controls
  # @param name required string ID of control's label/id
  # @param type required FORM_CHECKBOX|FORM_RADIO
  # @param options required ['value'...] or {"value" => 'Label for value'} of all values
  # @param selected optional 'value' or ['value'...] of all selected values
  def _whimsy_forms_checkradio(**args)
    return unless args[:name]
    return unless args[:type]
    return unless args[:options]
    args[:label] ||= 'Select value(s)'
    args[:id] = args[:name]
    args[:aria_describedby] = "#{args[:name]}_help" if args[:helptext]
    args[:selected] = [args[:selected]] if args[:selected].kind_of?(String)
    _whimsy_control_wrapper(args) do
      # Construct list of all :options; mark any that are in :selected
      if args[:options].kind_of?(Array)
        args[:options].each do |val|
          checked = true if args[:selected]&.include?(val.to_s)
          _label class: "#{args[:type]}-inline" do
            _input! type: args[:type], name: args[:name], id: args[:id], value: val, class: args[:class],
                    aria_describedby: args[:aria_describedby], checked: checked do
              _! val
            end
          end
        end
      elsif args[:options].kind_of?(Hash)
        args[:options].each do |val, disp|
          checked = true if args[:selected]&.include?(val.to_s)
          _label class: "#{args[:type]}-inline" do
            _input! type: args[:type], name: args[:name], id: args[:id], value: val, class: args[:class],
                    aria_describedby: args[:aria_describedby], checked: checked do
              _! disp
            end
          end
        end
      end
    end
  end

  # Gather POST form data into submission Hash
  # @returns {field: 'string', field2: ['array', 'only for', 'multivalue'] ...}
  def _whimsy_params2formdata(params)
    formdata = {}
    params.each do |k, v|
      v && (v.length == 1) ? formdata[k] = v[0] : formdata[k] = v
    end
    return formdata
  end

end
