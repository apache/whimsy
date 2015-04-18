#
# Routing request based on path and query information in the URL
#
# Additionally provides defaults for color and title, and 
# determines what buttons are required.
#

class Router
  @@traversal = :agenda
  @@buttons = []

  def self.traversal
    @@traversal
  end

  def self.buttons
    @@buttons
  end

  # route request based on path and query from the window location (URL)
  def self.route(path, query)
    @@traversal = :agenda
    @@buttons = []

    if not path or path == '.'
      item = Agenda

    elsif path == 'search'
      item = {view: Search, query: query}

    elsif path == 'comments'
      item = {view: Comments}

    elsif path == 'queue'
      item = {view: Queue, title: 'Queued approvals and comments'}

    elsif path =~ %r{^queue/[-\w]+$}
      @@traversal = :queue
      item = Agenda.find(path[6..-1])

    elsif path =~ %r{^shepherd/queue/[-\w]+$}
      @@traversal = :shepherd
      item = Agenda.find(path[15..-1])

    elsif path =~ %r{^shepherd/\w+$}
      shepherd = path[9..-1]
      item = {view: Shepherd, shepherd: shepherd,
        title: "Shepherded by #{shepherd}"}

    elsif path == 'help'
      item = {view: Help}

    else
      item = Agenda.find(path)
    end

    # bail unless an item was found
    return unless item

    # provide defaults for required properties
    item.color ||= 'blank'
    item.title ||= item.view.displayName

    # retain for later use
    Main.view = nil
    Main.item = item

    # determine what buttons are required, merging defaults, form provided
    # overrides, and any overrides provided by the agenda item itself
    buttons = item.buttons
    buttons = item.view.buttons().concat(buttons || []) if item.view.buttons
    if buttons
      @@buttons = buttons.map do |button|
        props = {text: 'button', attrs: {className: 'btn'}, form: button.form}

        # form overrides
        form = button.form
        if form and form.button
          for name in form.button
            if name == 'text'
              props.text = form.button.text
            elsif name == 'class' or name == 'classname'
              props.attrs.className += " #{form.button[name].gsub('_', '-')}"
            else
              props.attrs[name.gsub('_', '-')] = form.button[name]
            end
          end
        else
          # no form or form has no separate button: so this is just a button
          props.delete 'text'
          props.type = button.button || form
          props.attrs = {item: item, server: Server}
        end

        # item overrides
        for name in button
          if name == 'text'
            props.text = button.text
          elsif name == 'class' or name == 'classname'
            props.attrs.className += " #{button[name].gsub('_', '-')}"
          elsif name != 'form'
            props.attrs[name.gsub('_', '-')] = button[name]
          end
        end

        return props
      end
    end

    return item
  end
end
