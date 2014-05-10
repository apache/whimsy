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

      if vars.item === undefined
        @item = {}
        @next = nil
        @prev = nil
        @title = ''
      else
        @item = vars.item
        @next = vars.item.next
        @prev = vars.item.prev
        @title = vars.item.title
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
      $http.get("/test/roster/json/ldap").success {}
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
      if Minutes.complete
        if $rootScope.mode == :secretary and
          not Minutes.posted.include? @agenda_file.sub('_agenda_', '_minutes_')
          Actions.add 'draft-minutes-button', 'draft-minutes.html'
        end
      elsif Agenda.stop and Date.new().getTime() < Agenda.stop
        Actions.add 'special-order-button'
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
    @q_ready = []
    @q_comments = []
    watch 'pending.update + agenda.update' do
      @q_approvals.clear()
      @agenda.each do |item|
        @q_approvals << item if @pending.approved.include? item.attach
      end

      comments = @pending.comments
      @q_comments.clear()
      @agenda.each do |item|
        if comments[item.attach]
          item.comment = comments[item.attach]
          @q_comments << item
        end
      end

      @q_ready.clear()
      Agenda.ready().each do |item|
        @q_ready << item unless @q_approvals.include? item
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
    show = filter(:show)

    watch 'agenda.update + pending.update' do
      $rootScope.unseen_comments =
        @agenda.any? { |item| show(item, seen: @pending.seen) }
      $rootScope.seen_comments = !Object.keys(@pending.seen).empty?
    end

    on :toggleComments do |event, state|
      @toggle = state
    end

    # make comment split filter available as a function
    @csplit = filter(:csplit)

    Actions.add 'mark-seen-button'
    Actions.add 'toggle-seen-button'
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
    def save()
      data = {attach: @item.attach, initials: @initials, comment: @comment,
        agenda: Data.get('agenda')}

      $http.post('../json/comment', data).success { |response|
        Pending.put response
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
    @baseline = @report = @item.report || @item.text
    @digest = @item.digest

    watch @item.digest do |value|
      if value != @digest 
        @digest = value
        unless ~'.modal-open'.empty? or @disabled
          @disabled = true
          alert 'Edit Conflict'
        end
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
      @report = Flow.text(@report)
    end

    def cancel()
      ~'#post-report-form'.modal(:hide)
      @baseline = @report = @item.report || @item.text
      @disabled = false
    end

    def save()
      data = {attach: @item.attach, report: @report, agenda: Data.get('agenda'),
        message: @message, digest: @digest}

      data.fulltitle = @item.fulltitle if @item.fulltitle

      @disabled = true
      $http.post('../json/post', data).success { |response|
        Agenda.put response
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
    @date = Data.get('agenda')[/(\d+_\d+_\d+)/, 1]
    @draft = Minutes.draft
    @message ||= "Draft minutes for #{@date.gsub('_', '-')}"

    # fetch a current draft
    def draftMinutes()
      $http.get("/text/draft/#{@date}").then do |response|
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

  controller :Approve do
    def approve_label
      if Pending.approved.include? @item.attach
        'unapprove'
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
    if not @text
      if @item.title == 'Roll Call'
        @text = @item.text
        @text.sub! /^ASF members[\s\S]*?\n\n/m, '' # remove leading paragraph
        @text.gsub! /\s*\(expected.*?\)/, '' # remove (expected...)
      elsif @item.title == 'Action Items'
        @text = @item.text
      end
    end

    @previous_meeting = (@item.attach =~ /^3\w/)

    def save()
      data = {title: @item.title, text: @text, agenda: Data.get('agenda')}

      $http.post('../json/minute', data).success { |response|
        Minutes.put response
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception
      }.finally {
        ~'#minute-form'.modal(:hide)
      }
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

    def save()
      data = {title: @item.title, text: @text, agenda: Data.get('agenda')}

      $http.post('../json/minute', data).success { |response|
        Minutes.put response
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
    section = $routeParams.section || $routeParams.qsection

    # find agenda item, add relevant buttons
    watch 'agenda.update' do
      item = @agenda.find {|item| item.href == section}
      if item
        if $routeParams.section
          $scope.layout item: item
        else
          Agenda.ready()
          $scope.layout item: item,
            prev: item.qprev,
            prev_href: (item.qprev ? item.qprev.qhref : nil),
            next: item.qnext,
            next_href: (item.qnext ? item.qnext.qhref : nil)
        end

        unless Date.new().getTime() > Agenda.stop
          unless item.comments === undefined
            Actions.add 'comment-button', 'comment.html'
          end

          if item.attach =~ /^(\d|7?[A-Z]+)$/
            if item.missing
              $rootScope.post_button_text = 'post report'
              @post_form_title = 'Post report'
            elsif item.attach =~ /^7/
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
        end

      else
        $scope.layout item: {title: 'not found'}
      end
    end

    if @mode == :secretary
      watch @agenda.update + Minutes.status do |value|
        item = @agenda.find {|item| item.href == section}
        if item and Minutes.ready
          if item.attach =~ /^7\w$/
            Actions.add 'vote-button', 'vote.html'
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
