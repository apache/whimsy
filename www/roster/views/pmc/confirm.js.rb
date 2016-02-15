#
# Confirmation dialog
#

class PMCConfirm < React
  def initialize
    @text = 'text'
    @color = 'btn-default'
    @button = 'OK'
  end

  def render
    _div.modal.fade.confirm! tabindex: -1 do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header.bg_info do
            _button.close 'x', data_dismiss: 'modal'
            _h4.modal_title 'Confirm Request'
          end

          _div.modal_body do
            _p @text
          end

          _div.modal_footer do
            _button.btn.btn_default 'Cancel', data_dismiss:"modal"
            _button.btn @button, class: @color, onClick: self.post
          end
        end
      end
    end
  end

  def componentDidMount()
    jQuery('#confirm').on('show.bs.modal') do |event|
      button = event.relatedTarget
      @id = button.parentNode.dataset.id
      @action = button.dataset.action
      @text = button.dataset.confirmation
      @color = button.classList[1]
      @button = button.textContent
    end
  end

  def post()
    # parse action extracted from the button
    targets = @action.split(' ')
    action = targets.shift()

    # construct arguments to fetch
    args = {
      method: 'post',
      credentials: 'include',
      headers: {'Content-Type' => 'application/json'},
      body: {pmc: @@pmc, id: @id, action: action, targets: targets}.inspect
    }

    fetch('actions/committee', args).then {|response|
      content_type = response.headers.get('content-type') || ''
      if response.status == 200 and content_type.include? 'json'
        response.json().then do |json|
          @@update.call(json)
        end
      else
        alert "#{response.status} #{response.statusText}"
      end
      jQuery('#confirm').modal(:hide)
    }.catch {|error|
      alert errror
      jQuery('#confirm').modal(:hide)
    }
  end
end
