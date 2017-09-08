#
# Modify People's role in a project
#

class ProjectMod < Vue::Mixin
  def mounted()
    jQuery("##{$options.mod_tag}").on('show.bs.modal') do |event|
      button = event.relatedTarget
      setTimeout(500) { jQuery("##{$options.mod_tag} input").focus() }

      selected = []
      roster = @@project.roster
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
        project: @@project.id, 
        ids: @people.map {|person| person.id}.join(','), 
        action: action, 
        targets: targets
      }.inspect
    }

    @disabled = true
    Polyfill.require(%w(Promise fetch)) do
      fetch($options.mod_action, args).then {|response|
        content_type = response.headers.get('content-type') || ''
        if response.status == 200 and content_type.include? 'json'
          response.json().then do |json|
            Vue.emit :update, json
          end
        else
          alert "#{response.status} #{response.statusText}"
        end

        jQuery("##{$options.mod_tag}").modal(:hide)
        @disabled = false
      }.catch {|error|
        alert error
        jQuery("##{$options.mod_tag}").modal(:hide)
        @disabled = false
      }
    end
  end
end
