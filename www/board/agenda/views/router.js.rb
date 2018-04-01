#
# Routing request based on path and query information in the URL
#
# Additionally provides defaults for color and title, and 
# determines what buttons are required.
#
# Returns item, buttons, and options

class Router
  # route request based on path and query from the window location (URL)
  def self.route(path, query)
    options = {}

    if not path or path == '.'
      item = Agenda

    elsif path == 'search'
      item = {view: Search, query: query}

    elsif path == 'comments'
      item = {view: Comments}

    elsif path == 'backchannel'
      item = {view: Backchannel, title: 'Agenda Backchannel',
        online: Server.online}

    elsif path == 'queue'
      item = {view: Queue, title: 'Queued approvals and comments'}
      item.title = 'Queued comments' unless User.role == :director

    elsif path == 'flagged'
      item = {view: Flagged, title: 'Flagged reports'}

    elsif path == 'rejected'
      item = {view: Rejected, title: 'Reports which were NOT accepted'}

    elsif path == 'missing'
      buttons = [{form: InitialReminder}, {button: FinalReminder}]

      if Agenda.index.any? {|item| item.nonresponsive}
        buttons << {form: ProdReminder}
      end

      item = {view: Missing, title: 'Missing reports', buttons: buttons}

    elsif path =~ %r{^flagged/[-\w]+$}
      item = Agenda.find(path[8..-1])
      options = {traversal: :flagged}

    elsif path =~ %r{^queue/[-\w]+$}
      item = Agenda.find(path[6..-1])
      options = {traversal: :queue}

    elsif path =~ %r{^shepherd/queue/[-\w]+$}
      item = Agenda.find(path[15..-1])
      options = {traversal: :shepherd}

    elsif path =~ %r{^shepherd/\w+$}
      shepherd = path[9..-1]

      item = {view: Shepherd, shepherd: shepherd, next: nil, prev: nil,
        title: "Shepherded by #{shepherd}"}

      # determine next/previous links
      Agenda.index.each do |i|
        if i.shepherd and i.comments
          next if i.shepherd.include? ' '

          href = "shepherd/#{i.shepherd}"
          if i.shepherd > shepherd
            if not item.next or item.next.href > href
              item.next = {title: i.shepherd, href: href}
            end
          elsif i.shepherd < shepherd
            if not item.prev or item.prev.href < href
              item.prev = {title: i.shepherd, href: href}
            end
          end
        end
      end

    elsif path == 'feedback'
      item = {view: Feedback, title: 'Send Feedback'}

    elsif path == 'help'
      item = {view: Help}

    elsif path == 'bootstrap.html'
      item = {view: BootStrapPage, title: ' '}

    elsif path == 'cache/'
      item = {view: CacheStatus}

    elsif path =~ %r{^cache/}
      item = {view: CachePage}

    elsif path == 'fy23'
      item = {view: FY23, title: 'FY23 Budget Worksheet', color: 'available',
        prev: {title: 'Discussion Items', href: 'Discussion-Items'},
        next: {title: 'Action Items', href: 'Action-Items'}}

    else
      item = Agenda.find(path)

      if path == 'Discussion-Items' and Agenda.date =~ /^2018-02/
        item.next = {title: 'FY23 Budget Worksheet', href: 'fy23'}
      end
    end

    # bail unless an item was found
    return {} unless item

    # provide defaults for required properties
    item.color ||= 'blank'

    if not item.title
      item.title = item.view.options.name.
        gsub(/(^|-)\w/) {|c| return c.upcase()}.
        gsub('-', ' ').strip()
    end

    # determine what buttons are required, merging defaults, form provided
    # overrides, and any overrides provided by the agenda item itself
    buttons = item.buttons
    buttons = item.view.buttons().concat(buttons || []) if item.view.buttons
    if buttons
      buttons = buttons.map do |button|
        props = {text: 'button', attrs: {class: 'btn'}, form: button.form}

        # form overrides
        form = button.form
        if form and form.button
          for name in form.button
            if name == 'text'
              props.text = form.button.text
            elsif name == 'class' or name == 'classname'
              props.attrs.class += " #{form.button[name].gsub('_', '-')}"
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
            props.attrs.class += " #{button[name].gsub('_', '-')}"
          elsif name != 'form'
            props.attrs[name.gsub('_', '-')] = button[name]
          end
        end

        # clear modals
        document.body.classList.remove('modal-open') if defined? document

        return props
      end
    end

    return {item: item, buttons: buttons, options: options}
  end
end
