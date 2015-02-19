#!/usr/bin/ruby

# main application, consisting of a router and a number of controllers

module Angular::AsfBoardAgenda
  use :AsfBoardServices, :AsfBoardFilters, :AsfBoardDirectives

  $locationProvider.html5Mode(true).hashPrefix('!')

  # route request based on fragment identifier
  case $routeProvider
  when '/help'
    templateUrl '../partials/help.html'
    controller :Help

  when '/'
    templateUrl '../partials/index.html'
    controller :Index

  when '/queue'
    templateUrl '../partials/pending.html'
    controller :PendingItems

  when '/comments'
    templateUrl '../partials/comments.html'
    controller :Comments

  when '/queue/:qsection'
    templateUrl '../partials/section.html'
    controller :Section

  when '/shepherd/queue/:sqsection'
    templateUrl '../partials/section.html'
    controller :Section

  when '/shepherd/:name'
    templateUrl '../partials/shepherd.html'
    controller :Shepherd

  when '/search'
    templateUrl '../partials/search.html'
    controller :Search

  when '/:section'
    templateUrl '../partials/section.html'
    controller :Section

  else
    redirectTo '/'
  end

  controller :Layout do
    @toc = Agenda.index
    @item = {}
    @next = nil
    @prev = nil
    @search = {text: ''}

    def layout(vars)
      Actions.reset() unless vars.item and @item.title == vars.item.title
      @buttons = Actions.buttons

      @next = nil
      @prev = nil

      if vars.item === undefined
        @item = {}
        @title = ''
      else
        @item = vars.item
        @title = vars.item.title
        @next = vars.item.next unless vars.hasOwnProperty(:next)
        @prev = vars.item.prev unless vars.hasOwnProperty(:prev)
      end

      @title = vars.title unless vars.title === undefined
      @next = vars.next unless vars.next === undefined
      @prev = vars.prev unless vars.prev === undefined

      @next_href = @next.href if @next
      @prev_href = @prev.href if @prev

      @next_href = vars.next_href unless vars.next_href === undefined
      @prev_href = vars.prev_href unless vars.prev_href === undefined

      @user = Data.get('availid')

      if Data.get('initials')
        $rootScope.mode ||= :director
      elsif %w(clr jcarman).include? @user
        $rootScope.mode ||= :secretary
      else
        $rootScope.mode ||= :guest
      end

      @firstname = Data.get('firstname')
    end

    # toggle info display
    def infoToggle()
      @info = (@info ? nil : 'open')
    end

    def queued
      Pending.count
    end

    # prefetch roster info
    if $location.host() == 'whimsy.apache.org'
      $http.get("/roster/json/ldap").success {}
    end
  end

  # controller for the index page
  controller :Index do
    Minutes.get()
    @agenda = Agenda.get()
    @agenda_file = Data.get('agenda')

    title = @agenda_file[/\d+_\d+_\d+/].gsub(/_/,'-')

    agendas = ~'#agendas li'.to_a.map {|li| li.textContent.trim()}
    index = agendas.indexOf(@agenda_file)
    agendas = agendas.map do |text|
      text = text[/\d+_\d+_\d+/].gsub(/_/,'-')
      {href: "../#{text}/", title: text}
    end

    help = {href: 'help', title: 'Help'}
    $scope.layout title: title, next: agendas[index+1] || help,
      prev: agendas[index-1] || help
    Actions.add 'refresh-button'

    @forms = Actions.forms
    watch Minutes.complete + Agenda.stop do
      if Agenda.stop and Date.new().getTime() < Agenda.stop
        Actions.add 'special-order-button' unless Minutes.complete
      end

      if $rootScope.mode == :secretary
        if Minutes.posted.include? @agenda_file.sub('_agenda_', '_minutes_')
          Actions.add 'publish-minutes-button', 'publish-minutes.html'
        elsif Minutes.complete
          Actions.add 'draft-minutes-button', 'draft-minutes.html'
        end
      end
    end
  end

  # controller for the help page
  controller :Help do
    $scope.layout title: 'Help'

    def set_mode(mode)
      $rootScope.mode = mode
    end
  end

  # controller for the pending pages
  controller :PendingItems do
    @agenda = Agenda.get()
    @pending = Pending.get()
    firstname = Data.get('firstname')

    $scope.layout title: 'Queued approvals and comments',
      prev: ({title: 'Shepherd', href: "shepherd/#{firstname}"} if firstname)

    Actions.add 'refresh-button'

    @q_approvals = []
    @q_rejected = []
    @q_ready = []
    @q_comments = []
    watch 'pending.update + agenda.update' do
      @q_approvals.clear()
      @q_rejected.clear()
      @agenda.each do |item|
        @q_approvals << item if @pending.approved.include? item.attach
        @q_rejected  << item if @pending.rejected.include? item.attach
      end

      comments = @pending.comments
      initials = Data.get('initials')
      @q_comments.clear()
      @q_ready.clear()
      @agenda.each do |item|
        if comments[item.attach]
          item.comment = comments[item.attach]
          @q_comments << item
        end

        unless @q_approvals.include? item or @q_rejected.include? item
          @q_ready << item if item.ready and not item.approved.include? initials
        end
      end
    end

    watch 'q_comments.length + q_approvals.length' do |after, before|
      Actions.add 'commit-button' if after > 0

      message = []

      if @q_approvals.length > 0 and @q_approvals.length <= 6
        message << "Approve #{
          @q_approvals.map {|item| item.title}.join(', ')}"
      elsif @q_approvals.length > 1
        message << "Approve #{ @q_approvals.length} reports"
      end

      if @q_comments.length > 0 and @q_comments.length <= 6
        message << "Comment on #{
          @q_comments.map {|item| item.title}.join(', ')}"
      elsif @q_comments.length > 1
        message << "Comment on #{ @q_comments.length} reports"
      end

      @commit_message = message.join("\n")
    end
  end

  controller :Commit do
    def commit()
      data = {message: @commit_message}

      @disabled = true
      $http.post('../json/commit', data).success { |response|
        Agenda.put response.agenda
        Pending.put response.pending
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception
      }.finally {
        ~'#commit-form'.modal(:hide)
        @disabled = false
      }
    end
  end

  # controller for the comments pages
  controller :Comments do
    firstname = Data.get('firstname')
    $scope.layout title: "Comments",
      prev: {title: 'Search', href: 'search'},
      next: ({title: 'Shepherd', href: "shepherd/#{firstname}"} if firstname)
    @agenda = Agenda.get()
    @pending = Pending.get()
    @toggle = false

    watch 'agenda.update + pending.update' do
      $rootScope.any_seen = !@pending.seen.keys().empty?
    end

    on :toggleComments do |event, state|
      @toggle = state
    end

    # make comment split filter available as a function
    csplit = filter(:csplit)

    Actions.add 'mark-seen-button'
    Actions.add 'toggle-seen-button'

    # produce a stable list of visible comments
    $rootScope.any_visible = false
    $rootScope.any_hidden = false
    def visible_comments
      $rootScope.any_hidden = false
      @visible ||= []
      result = []
      @agenda.each do |item|
        show = []
        seen = csplit(@pending.seen[item.attach])

        csplit(item.comments).each do |comment|
          if seen.include?(comment) and not @toggle
            $rootScope.any_hidden = true
          elsif comment.trim()
            show << comment 
          end
        end

        unless show.empty?
          result << {title: item.title, href: item.href, comments: show} 
        end
      end

      angular.copy result, @visible unless angular.equals(result, @visible)
      $rootScope.any_visible = (not @visible.empty?)
      @visible
    end
  end

  controller :MarkSeen do
    @undo = nil
    @label = 'mark seen'
    @disabled = false
    def click()
      @disabled = true

      # gather up the comments
      if @undo
        seen = @undo
      else
        seen = {}
        Agenda.get().each do |item|
          seen[item.attach] = item.comments if item.comments
        end
      end

      data = { seen: seen, agenda: Data.get('agenda') }

      $http.post('../json/markseen', data).success { |response|
        if @undo
          @undo = nil
          @label = 'mark seen'
        else
          @undo = angular.copy(Pending.get().seen)
          @label = 'undo mark'
        end

        Pending.put response
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception
      }.finally {
        @disabled = false
      }
    end
  end

  controller :ToggleComments do
    @label = 'show'
    def click()
      broadcast! :toggleComments, (@label == 'show')
      @label = (@label == 'show' ? 'hide' : 'show')
    end
  end

  # controller for the shepherd pages
  controller :Shepherd do
    @agenda = Agenda.get()
    @name = $routeParams.name
    $scope.layout title: "Shepherded By #{@name}",
      prev: {title: 'Comments', href: 'comments'},
      next: {title: 'Queue', href: 'queue'}

    watch 'agenda.update' do
      @agenda.each do |item|
        if item.title == 'Action Items'
          @actions = item
          @assigned = item.text.split("\n\n").select do |item|
            item =~ /^\* *#{$routeParams.name}/m
          end
        end
      end
    end
  end

  controller :Comment do
    @text = {draft: @comment, base: @comment}
    $rootScope.comment_text = @text

    def save(comment)
      data = {attach: @item.attach, initials: @initials, comment: comment,
        agenda: Data.get('agenda')}

      $http.post('../json/comment', data).success { |response|
        Pending.put response
        @text = {draft: comment, base: comment}
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception
      }.finally {
        ~'#comment-form'.modal(:hide)
      }
    end
  end

  controller :PostReport do
    @disabled = false
    @report = @item.report || @item.text
    if @item.title == 'President'
      @report.sub! /\s*Additionally, please see Attachments \d through \d\./, ''
    end
    @baseline = @report
    @digest = @item.digest

    watch @item.digest do |value|
      if value != @digest 
        @digest = value
        unless ~'.modal-open'.empty? or @disabled or @updated
          @disabled = true
          alert 'Edit Conflict'
        end
        @updated = false
      end
    end

    if @post_button_text == 'edit report'
      @message = "Edit #{@item.title} Report"
    elsif @post_button_text == 'edit resolution'
      @message = "Edit #{@item.title} Resolution"
    else
      @message = "Post #{@item.title} Report"
    end

    def reflow()
      indent = (@item.attach =~ /^4/ ? '        ' : '')
      @report = Flow.text(@report, indent)
    end

    def cancel()
      ~'#post-report-form'.modal(:hide)
      @report = @baseline
      @disabled = false
    end

    def save()
      data = {attach: @item.attach, report: @report, agenda: Data.get('agenda'),
        message: @message, digest: @digest}

      data.fulltitle = @item.fulltitle if @item.fulltitle

      @disabled = true
      $http.post('../json/post', data).success { |response|
        Agenda.put response
        @updated = true
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception
      }.finally {
        ~'#post-report-form'.modal(:hide)
        @disabled = false
      }
    end

    watch @report do |value|
      if value and value.split("\n").any? {|line| line.length > 80}
        @reflow_class = 'btn-danger'
      else
        @reflow_class = 'btn-default'
      end
    end
  end

  controller :DraftMinutes do
    @date = Data.get('agenda')[/\d+_\d+_\d+/]
    @draft = Minutes.draft
    @message ||= "Draft minutes for #{@date.gsub('_', '-')}"

    # fetch a current draft
    def draftMinutes()
      $http.get("../text/draft/#{@date}").then do |response|
        @draft[@date] = response.data
      end
    end

    def save()
      minutes = Data.get('agenda').sub('_agenda_', '_minutes_')
      data = {minutes: minutes, message: @message, draft: @draft[@date]}

      @disabled = true
      $http.post('../json/draft', data).success { |response|
        Minutes.posted << minutes
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception
      }.finally {
        ~'#draft-minutes-form'.modal(:hide)
        @disabled = false
      }
    end
  end

  controller :PublishMinutes do
    months = %w(January February March April May June July August September
      October November December)

    def formatDate(date)
      date = Date.new(date.gsub('_', '/'))
      return "#{date.getDate()} #{months[date.getMonth()]} #{date.getYear()+1900}"
    end

    def summarize(agenda, date)
      result = "- [#{$scope.formatDate(date)}]" +
              "(../records/minutes/#{date[0..3]}/board_minutes_#{date}.txt)\n"
      agenda.each do |item|
        if item.attach =~ /^7\w$/
          result += "    * #{item.title.
            gsub(/(.{1,76})(\s+|$)/, "$1\n      ").
            gsub(/ +$/, '')}"
        end
      end
      return result
    end

    def publishMinutes()
      if @item.attach
        date = @item.text[/board_minutes_(\d+_\d+_\d+)\.txt/, 1]
        if date
          $http.get("../#{date.gsub('_', '-')}.json").success { |response|
            broadcast! :pubSummary, $scope.summarize(response, date), date
          }
        end
      else
        date = Data.get('agenda')[/\d+_\d+_\d+/]
        broadcast! :pubSummary, $scope.summarize(Agenda.get(), date), date
      end
    end

    on :pubSummary do |event, summary, date|
      @summary = summary
      @date = date
      @message = "Publish #{$scope.formatDate(date)} minutes"
    end

    def save()
      minutes = "board_minutes_#{@date}.txt"
      data = {date: @date, minutes: minutes, message: @message, 
        summary: @summary}

      @disabled = true
      $http.post('../json/publish', data).success { |response|
        index = Minutes.posted.indexOf(minutes)
        Minutes.posted.slice(index, 1) if index > -1
        window.open('https://cms.apache.org/www/publish', '_blank').focus()
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception
      }.finally {
        ~'#publish-minutes-form'.modal(:hide)
        @disabled = false
      }
    end
  end

  controller :SpecialOrder do
    @title = ''

    def save()
      data = {attach: '7?', title: @title, report: @report,
        agenda: Data.get('agenda')}

      @disabled = true
      $http.post('../json/post', data).success { |response|
        Agenda.put response
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception
      }.finally {
        ~'#special-order-form'.modal(:hide)
        @disabled = false
        @title = @report = ''
      }
    end
  end

  controller :Refresh do
    @disabled = false
    def click()
      data = {agenda: Data.get('agenda')}

      @disabled = true
      $http.post('../json/refresh', data).success { |response|
        Agenda.put response
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception
      }.finally {
        @disabled = false
      }
    end
  end

  controller :Attend do
    def attend_label
      if @item.people[@user] and @item.people[@user].attending
        'regrets'
      else
        'attend'
      end
    end

    def click()
      if @attend_label == 'regrets'
        data = {action: 'regrets', name: @item.people[@user].name}
      else
        data = {action: 'attend', userid: @user}
      end

      data.agenda = Data.get('agenda')

      @disabled = true
      $http.post('../json/attend', data).success { |response|
        Agenda.put response
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception
      }.finally {
        @disabled = false
      }
    end
  end

  controller :Approve do
    def approve_label
      if Pending.approved.include? @item.attach
        'unapprove'
      elsif Actions.control
        'reject'
      else
        'approve'
      end
    end

    def click()
      data = {attach: @item.attach, request: self.approve_label,
        initials: Data.get('initials'), agenda: Data.get('agenda')}

      $http.post('../json/approve', data).success { |response|
        Pending.put response
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception
      }
    end
  end

  # Secretary take minutes
  controller :Minute do
    rollcall =  @minutes['Roll Call'] || @agenda[1].text
    pattern = Regexp.new('\n   ( [a-z]*[A-Z][a-zA-Z]*\.?)+', 'g')
    @attendees = []
    while (match=pattern.exec(rollcall)) do
      @attendees << match[0].sub(/^\s+/, '').split(' ').first
    end
    @attendees.sort!()

    if @minutes[@item.title]
      @text = {base: @minutes[@item.title]}
    elsif @item.title == 'Roll Call'
      @text = {base: @item.text}
      @text.base.sub! /^ASF members[\s\S]*?\n\n/m, '' # remove 1st paragraph
      @text.base.gsub! /\s*\(expected.*?\)/, '' # remove (expected...)
    elsif @item.title == 'Action Items'
      @text = {base: @item.text}
    else
      @text = {base: ''}
    end

    @text.draft ||= @text.base

    @previous_meeting = (@item.attach =~ /^3\w/)

    def save(text = @text.draft)
      data = {title: @item.title, text: text, agenda: Data.get('agenda')}

      $http.post('../json/minute', data).success { |response|
        @text.base = @text.draft = text
        Minutes.put response
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception
      }.finally {
        ~'#minute-form'.modal(:hide)
      }
    end

    @ai = {assignee: '', text: ''}
    @ai.assignee = @item.shepherd.split(' ').first if @item.shepherd
    unless @item.report or @item.text
      @ai.text = "pursue a report for #{@item.title}" 
    end

    def add_ai()
      @text.draft = @text.draft.sub(/\s+$/, '') + "\n\n" if @text.draft
      @text.draft = (@text.draft || '') +
        Flow.comment(@ai.text, "@#{@ai.assignee}")
      @ai.text = ''
    end
  end

  # Secretary take vote
  controller :Vote do
    rollcall =  @minutes['Roll Call'] || @agenda[1].text
    @directors = rollcall[/Directors.*Present:\n\n((.*\n)*?)\n/,1].
      sub(/\n$/, '')

    if (Date.new().getMonth() + @item.attach.charCodeAt(1)) % 2
      @votetype = "Roll call"
    else
      @votetype = "Reverse roll call"
      @directors = @directors.split("\n").reverse().join("\n")
    end

    @fulltitle = @item.fulltitle || @item.title
    text = $scope['$parent'].text
    @text = {base: text, draft: text}

    def save(text = @text.draft)
      data = {title: @item.title, text: text, agenda: Data.get('agenda')}

      $http.post('../json/minute', data).success { |response|
        Minutes.put response
        @text = {base: text, draft: text}
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception
      }.finally {
        ~'#vote-form'.modal(:hide)
      }
    end
  end

  # Secretary timestamp for Call to Order and Adjournment
  controller :Timestamp do
    def click()
      data = {title: @item.title, action: 'timestamp', agenda: Data.get('agenda')}

      $http.post('../json/minute', data).success { |response|
        Minutes.put response
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception
      }
    end
  end

  # controller for the section pages
  controller :Section do
    @forms = Actions.forms
    @agenda = Agenda.get()
    @initials = Data.get('initials')
    @minutes = Minutes.get()
    @cflow = Flow.comment

    # fetch section from the route parameters
    section = $routeParams.section || $routeParams.qsection ||
      $routeParams.sqsection

    # find agenda item, add relevant buttons
    watch 'agenda.update' do
      item = @agenda.find {|item| item.href == section}
      if item
        if $routeParams.section
          $scope.layout item: item
        elsif $routeParams.qsection
          $scope.layout item: item,
            prev: item.qprev,
            prev_href: (item.qprev ? item.qprev.qhref : nil),
            next: item.qnext,
            next_href: (item.qnext ? item.qnext.qhref : nil)
        else
          $scope.layout item: item,
            prev: item.sqprev,
            prev_href: (item.sqprev ? item.sqprev.sqhref : nil),
            next: item.sqnext,
            next_href: (item.sqnext ? item.sqnext.sqhref : nil)
        end

        unless Date.new().getTime() > Agenda.stop
          unless item.comments === undefined
            Actions.add 'comment-button', 'comment.html'
          end

          if item.attach =~ /^(\d|7?[A-Z]+|4[A-Z])$/
            if item.missing
              $rootScope.post_button_text = 'post report'
              @post_form_title = 'Post report'
            elsif item.attach =~ /^7\w/
              $rootScope.post_button_text = 'edit resolution'
              @post_form_title = 'Edit resolution'
            else
              $rootScope.post_button_text = 'edit report'
              @post_form_title = 'Edit report'
            end
            Actions.add 'post-button', 'post.html'
          end

          if @mode==:director and (item.report or item.text)
            if item.approved and not item.approved.include? @initials
              Actions.add 'approve-button'
            end
          end

          if item.title == 'Roll Call' and not @minutes['Roll Call']
            Actions.add 'attend-button'
          end
        end

        if item.title == 'Action Items'
          def item.new_actions
            Minutes.new_actions
          end
        elsif item.attach =~ /^3[A-Z]$/
          date = item.text[/board_minutes_(\d+_\d+_\d+)\.txt/, 1]
          if date
            $http.get("../text/minutes/#{date}").success { |response|
              @minute_text = response
            }
          end
        elsif item.title == 'Adjournment' and @mode == :secretary
          @todo = TODO.get()
        end

      else
        $scope.layout item: {title: 'not found'}
      end
    end

    watch @agenda.update + Minutes.status do
      if @mode == :secretary
        item = @agenda.find {|item| item.href == section}
        if item and Minutes.ready
          if item.attach =~ /^7\w$/
            Actions.add 'vote-button', 'vote.html'
          elsif item.attach =~ /^3\w$/
            Actions.add 'minute-button', 'minute.html'
            if @minutes[@item.title] == 'approved' and 
              Minutes.posted.include? @item.text[/board_minutes_\w+\.txt/]
              Actions.add 'publish-minutes-button', 'publish-minutes.html'
            else
              Actions.remove 'publish-minutes-button'
            end
          elsif ['Call to order', 'Adjournment'].include? item.title
            if @minutes[item.title]
              Actions.remove 'timestamp-button'
              Actions.add 'minute-button', 'minute.html'

              if Minutes.complete 
                Actions.add 'draft-minutes-button', 'draft-minutes.html'
              end
            else
              Actions.add 'timestamp-button'
            end
          else
            Actions.add 'minute-button', 'minute.html'
          end

          minute_file = Data.get('agenda').sub('_agenda_', '_minutes_')
          if Minutes.posted.include? minute_file
            Actions.remove 'minute-button'
            Actions.remove 'draft-minutes-button'
          end
        end
      end
    end

    @pending = Pending.get()
    watch 'pending.update + agenda.update' do
      @comment = @pending.comments[@item.attach]
      $rootScope.comment_label =
        (@comment && @comment.length > 0 ? 'edit comment' : 'add comment')
    end

    watch @minutes[@item.title] do |value|
      @text = value
      $rootScope.minute_label =
        (@text && @text.length > 0 ? 'edit minutes' : 'add minutes')
    end

    def link(resolution)
      link = nil
      @agenda.each do |item|
        link = item.href if item.title == resolution
      end
      return link
    end

    def pmc_report
      @item.attach.match(/^[A-Z][A-Z]?$/)
    end

    firstname = Data.get('firstname')
    def mailto_class
      @item.shepherd.split(' ').first == firstname ? 'btn-primary' : 'btn-link'
    end

    def mailto()
      $window.location = "mailto:#{@item.chair_email}" +
        "?cc=private@#{@item.mail_list}.apache.org,board@apache.org" +
        "&subject=Missing%20#{@item.title}%20board%20report" +
        "&body=Dear%20#{@item.owner},%0A%0AThe%20board%20report%20for%20" +
        "#{@item.title}%20has%20not%20yet%20been%20submitted%20for%20this%20" +
        "month's%20board%20meeting.%20If%20you're%20unable%20to%20get%20it%20" +
        "in%20by%20twenty-four%20hours%20before%20meeting%20time,%20please%20" +
        "plan%20to%20report%20next%20month.%0A%0AThanks."
      $rootScope.comment_text.draft ||= 'Reminder email sent'
      ~'#comment-form'.modal(:show)
    end
  end

  controller :Search do
    @agenda = Agenda.get()
    $scope.layout title: "Search", next: {title: 'Comments', href: 'comments'}
    Actions.add 'refresh-button'

    @search.text = $location.search().q || ''
    @results = []

    def message
      if @agenda.length == 0
        'Loading...'
      elsif @search.text.length < 3
        'Please enter at least three characters'
      elsif @results.length == 0
        'No matches'
      end
    end

    def find_matches()
      history = @results
      matches = []
      if @search.text.length > 2
        search = @search.text.downcase()
        @agenda.each do |item|
          text = item.text || item.report
          if text and text.downcase().include? search
            snippets = []
            text.split(/\n\s*\n/).each do |paragraph|
              snippets << paragraph if paragraph.downcase().include? search
            end

            match = {item: item, snippets: snippets}
            matches <<
              (history.find {|prev| angular.equals(prev, match)} || match)
          end
        end
      end

      # For some reason `angular.copy matches, @matches` produces
      # "Maximum call stack size exceeded"
      @results.clear()
      angular.extend @results, matches
    end

    watch @search.text + @agenda.update do
      $scope.find_matches()
    end
  end
end
