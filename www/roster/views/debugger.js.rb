#
# Debugging tool shell
#
class Debugger < Vue
  def initialize
    @committer = {}
    @auth = {}
  end

  def render
    # Display auth status
    if @auth
      _div.alert.alert_success do 
        _ 'Whimsy Debugging: you are authd'
        _ "#{@auth}"
      end
    end
    _h2 "Welcome #{@committer.id}@apache.org"      
    # Test bar: allow testing of a string input
    _div.row key: 'databar' do
      _div.col_sm_6 do
        _input.form_control type: 'value', placeholder: 'value to use',
        value: @value
      end
      _div.col_sm_6 do
        _button.btn.btn_default 'LDAP Lookup', data_target: '#debugldap'
      end
    end
  end

end

class DebugLDAP < Vue
  options add_tag: "debugldap", add_action: 'actions/debugger'

  def initialize
    @search = []
  end

  def render
    _div.modal.fade id: $options.add_tag, tabindex: -1 do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header.bg_info do
            _button.close 'x', data_dismiss: 'modal'
            _h4.modal_title 'Do a debug LDAP Lookup'
          end
          _div.modal_body do
            _div.container_fluid do
              _div.form_group do
                _label.control_label.col_sm_3 'Search LDAP for', for:  'search-text'
                _div.col_sm_9 do
                  _div.input_group do
                    _input.form_control autofocus: true, value: @search, 
                      onInput: self.change
                    _span.input_group_addon do
                      _span.glyphicon.glyphicon_user aria_label: "LDAP search query"
                    end
                  end
                end
              end
            end
          end
          _div.modal_footer do
            _button.btn.btn_default 'Cancel', data_dismiss: 'modal'
            _button.btn.btn_primary "Search LDAP", 
              data_action: 'search ldap',
              onClick: self.post, disabled: (@search.empty?)
          end
        end
      end
    end
  end
end