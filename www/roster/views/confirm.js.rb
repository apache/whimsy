#
# Confirmation dialog
#

class Confirm < Vue
  def initialize
    @text = 'text'
    @color = 'btn-default'
    @button = 'OK'
    @disabled = false
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
            _span.status 'Processing request...' if @disabled
            _button.btn.btn_default 'Cancel', data_dismiss: 'modal',
              disabled: @disabled
            _button.btn @button, class: @color, onClick: self.post,
              disabled: @disabled
          end
        end
      end
    end
  end

  def mounted()
    jQuery('#confirm').on('show.bs.modal') do |event|
      button = event.relatedTarget
      @ids = button.parentNode.dataset.ids
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
      body: {
        project: @@project,
        ids: @ids,
        action: action,
        targets: targets
      }.inspect
    }

    @disabled = true
    Polyfill.require(%w(Promise fetch)) do
      fetch("actions/#{@@action}", args).then {|response|
        content_type = response.headers.get('content-type') || ''
        if response.status == 200 and content_type.include? 'json'
          response.json().then do |json|
            @@update.call(json)
          end
        else
          alert "#{response.status} #{response.statusText}"
        end
        jQuery('#confirm').modal(:hide)
        @disabled = false
      }.catch {|error|
        alert error
        jQuery('#confirm').modal(:hide)
        @disabled = false
      }
    end
  end
end
