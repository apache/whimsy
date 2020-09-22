#
# Add People to a PMC or podling
#

class ProjectAdd < Vue::Mixin
  def mounted()
    # autofocus when modal is shown
    jQuery("##{$options.add_tag}").on('show.bs.modal') do |event|
      setTimeout(500) do
         jQuery("##{$options.add_tag} input[autofocus]").focus()
      end
    end

    # clear input when modal is dismissed
    jQuery("##{$options.add_tag}").on('hidden.bs.modal') do |event|
      @people = []
    end
  end

  def add(person)
    @people << person
    Vue.forceUpdate()
    jQuery("##{$options.add_tag} input").focus()
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
      fetch($options.add_action, args).then {|response|

        # raises alert if the response is not successful JSON
        Utils.handle_json(response, lambda { |json| Vue.emit :update, json } )

        jQuery("##{$options.add_tag}").modal(:hide)
        @disabled = false
      }.catch {|error|
        alert error
        jQuery("##{$options.add_tag}").modal(:hide)
        @disabled = false
      }
    end
  end
end
