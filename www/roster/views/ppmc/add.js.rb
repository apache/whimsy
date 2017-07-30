#
# Add People to a project
#

class PPMCAdd < React
  def initialize
    @people = []
  end

  def render
    _div.modal.fade.ppmcadd! tabindex: -1 do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header.bg_info do
            _button.close 'x', data_dismiss: 'modal'
            _h4.modal_title 'Add People to the ' + @@ppmc.display_name +
	      ' Podling'
          end

          _div.modal_body do
            _div.container_fluid do

	      unless @people.empty?
                _table.table do
                  _thead do
                    _tr do
	              _th 'id'
	              _th 'name'
	              _th 'email'
	            end
                  end
                  _tbody do
                    @people.each do |person|
	              _tr do
	                _td person.id
	                _td person.name
	                _td person.mail[0]
	              end
	            end
                  end
                end
	      end

              _CommitterSearch add: self.add,
	        exclude: @@ppmc.roster.keys().
		  concat(@people.map {|person| person.id})
            end
          end

          _div.modal_footer do
            _span.status 'Processing request...' if @disabled

            _button.btn.btn_default 'Cancel', data_dismiss: 'modal',
              disabled: @disabled

	    plural = (@people.length > 1 ? 's' : '')

            if @@auth.ppmc
              _button.btn.btn_primary "Add as committer#{plural}", 
	        data_action: 'add committer',
	        onClick: self.post, disabled: (@people.empty?)

              _button.btn.btn_primary 'Add to PPMC', onClick: self.post,
	        data_action: 'add ppmc committer', disabled: (@people.empty?)
            end

            if @@auth.ipmc
              action = 'add mentor'
              action += ' ppmc committer' if @@auth.ppmc

              _button.btn.btn_primary "Add as mentor#{plural}", 
	        data_action: action, onClick: self.post,
                 disabled: (@people.empty?)
            end
          end
        end
      end
    end
  end

  def componentDidMount()
    jQuery('#pmcadd').on('show.bs.modal') do |event|
      button = event.relatedTarget
      setTimeout(500) { jQuery('#pmcadd input').focus() }
    end
  end

  def add(person)
    @people << person
    self.forceUpdate()
    jQuery('#pmcadd input').focus()
  end

  def post(event)
    button = event.currentTarget

    # parse action extracted from the button
    targets = button.dataset.action.split(' ')
    action = targets.shift()

    # construct arguments to fetch
    args = {
      method: 'post',
      credentials: 'include',
      headers: {'Content-Type' => 'application/json'},
      body: {
        project: @@ppmc.id, 
        ids: @people.map {|person| person.id}.join(' '), 
        action: action, 
        targets: targets
      }.inspect
    }

    @disabled = true
    Polyfill.require(%w(Promise fetch)) do
      fetch("actions/committee", args).then {|response|
        content_type = response.headers.get('content-type') || ''
        if response.status == 200 and content_type.include? 'json'
          response.json().then do |json|
            @@update.call(json)
          end
        else
          alert "#{response.status} #{response.statusText}"
        end
        jQuery('#pmcadd').modal(:hide)
        @disabled = false
      }.catch {|error|
        alert error
        jQuery('#pmcadd').modal(:hide)
        @disabled = false
      }
    end
  end
end
