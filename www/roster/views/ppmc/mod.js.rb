#
# Add People to a project
#

class PPMCMod < React
  def initialize
    @people = []
  end

  def render
    _div.modal.fade.ppmcmod! tabindex: -1 do
      _div.modal_dialog do
        _div.modal_content do
          _div.modal_header.bg_info do
            _button.close 'x', data_dismiss: 'modal'
            _h4.modal_title "Modify People's Roles in the " + 
              @@ppmc.display_name + ' Podling'
          end

          _div.modal_body do
            _div.container_fluid do
	      _table.table do
		_thead do
		  _tr do
		    _th 'id'
		    _th 'name'
		  end
		end
		_tbody do
		  @people.each do |person|
		    _tr do
		      _td person.id
		      _td person.name
		    end
		  end
		end
	      end
            end
          end

          _div.modal_footer do
            _span.status 'Processing request...' if @disabled

            _button.btn.btn_default 'Cancel', data_dismiss: 'modal',
              disabled: @disabled

            if @@auth.ppmc
	      # show add to PPMC button only if every person is not on the PPMC
	      if @people.all? {|person| !@@ppmc.owners.include? person.id}
		_button.btn.btn_primary "Add to PPMC", 
		  data_action: 'add ppmc',
		  onClick: self.post, disabled: (@people.empty?)
	      end
            end

            # show add as mentor button only if every person is not a mentor
            if @@auth.ipmc
              if @people.all? {|person| !@@ppmc.mentors.include? person.id}
                plural = (@people.length > 1 ? 's' : '')

                action = 'add mentor'
                if @people.any? {|person| !@@ppmc.owners.include? person.id}
	          action += ' ppmc'
                end

                _button.btn.btn_primary "Add as Mentor#{plural}", 
	          data_action: action, onClick: self.post,
                  disabled: (@people.empty?)
              end
            end

            # remove from all relevant locations
            remove_from = ['committer']
            if @people.any? {|person| @@ppmc.owners.include? person.id}
              remove_from << 'ppmc'
            end
            if @people.any? {|person| @@ppmc.mentors.include? person.id}
              remove_from << 'mentor'
            end

            _button.btn.btn_primary 'Remove from project', onClick: self.post,
	      data_action: "remove #{remove_from.join(' ')}"
          end
        end
      end
    end
  end

  def componentDidMount()
    jQuery('#ppmcmod').on('show.bs.modal') do |event|
      button = event.relatedTarget
      setTimeout(500) { jQuery('#ppmcmod input').focus() }

      selected = []
      roster = @@ppmc.roster
      for id in roster
        if roster[id].selected
          roster[id].id = id
          selected << roster[id]
        end
      end

      @people = selected
    end
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
      fetch("actions/ppmc", args).then {|response|
        content_type = response.headers.get('content-type') || ''
        if response.status == 200 and content_type.include? 'json'
          response.json().then do |json|
            @@update.call(json)
          end
        else
          alert "#{response.status} #{response.statusText}"
        end
        jQuery('#ppmcmod').modal(:hide)
        @disabled = false
      }.catch {|error|
        alert error
        jQuery('#ppmcmod').modal(:hide)
        @disabled = false
      }
    end
  end
end
