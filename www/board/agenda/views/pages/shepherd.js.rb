#
# A page showing all queued approvals and comments, as well as items
# that are ready for review.
#

class Shepherd < Vue
  def initialize
    @disabled = false
    @followup = []
  end

  def render
    shepherd = @@item.shepherd.downcase()

    actions = Agenda.find('Action-Items')
    if actions.actions.any? {|action| action.owner == @@item.shepherd}
      _h2 'Action Items'
      _ActionItems item: actions, filter: {owner: @@item.shepherd}
    end

    _h2 'Committee Reports'

    # list agenda items associated with this shepherd
    Agenda.index.each do |item|
      if item.shepherd and item.shepherd.downcase().start_with? shepherd
        _Link text: item.title, href: "shepherd/queue/#{item.href}",
          class: "h3 #{item.color}"

        _AdditionalInfo item: item, prefix: true

        # flag action
        if item.missing or not item.comments.empty?
          if item.attach =~ /^[A-Z]+$/
            mine = (shepherd == User.firstname ? 'btn-primary' : 'btn-link')

            _div.shepherd do
              _button.btn (item.flagged ? 'unflag' : 'flag'), class: mine,
                data_attach: item.attach,
                onClick: self.click, disabled: @disabled

              _Email item: item
            end
          end
        end
      end
    end

    # list feedback items that may need to be followed up
    followup = []
    @followup.each_pair do |title, item|
       next unless item.count == 1
       next unless item.shepherd == @@item.shepherd
       next if Agenda.index.any? {|item| item.title == title}
       item.title = title
       followup << item
    end

    unless followup.empty?
      _h2 'Feedback that may require followup'

      followup.each do |followup|
        link = followup.title.gsub(/[^a-zA-Z0-9]+/, '-')
        _a.h3.ready followup.title, href: "../#{@prior_date}/#{link}"

        splitComments(followup.comments).each do |comment|
          _pre.comment comment
        end
      end
    end
  end

  # Fetch followup items
  def mounted()
    # if cached, reuse
    if Shepherd.followup
      @followup = Shepherd.followup
      return
    end

    # determine date of previous meeting
    prior_agenda = Server.agendas[-2]
    return unless prior_agenda
    @prior_date = prior_agenda[/\d+_\d+_\d+/].gsub('_', '-')

    retrieve "../#{@prior_date}/followup.json", :json do |followup|
      Shepherd.followup = followup
      @followup = followup
    end
  end

  def click(event)
    data = {
      agenda: Agenda.file,
      initials: User.initials,
      attach: event.target.getAttribute('data-attach'),
      request: event.target.textContent
    }

    @disabled = true
    post 'approve', data do |pending|
      @disabled = false
      Pending.load pending
    end
  end
end
