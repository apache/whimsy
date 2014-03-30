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

    def layout(vars)
      @buttons = []
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
    def infoToggle
      @info = (@info ? nil : 'open')
    end

    watch Pending.count do |value|
      @queued = value
    end
  end

  # controller for the index page
  controller :Index do
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
    @buttons << 'refresh-button'

    @buttons << 'special-order-button'
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
      prev: ({title: 'Shepherd', href: "shepherd/#{firstname}"} if firstname),
      next: {title: 'Comments', href: 'comments'}

    @buttons << 'refresh-button'

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
      if after > 0 and !@buttons.include? 'commit-button'
        @buttons << 'commit-button' 
      end

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
    def commit
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
    initials = Data.get('initials')
    $scope.layout title: "Comments",
      prev: ({title: 'Queue', href: 'queue'} if initials)
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

    @buttons << 'mark-seen-button'
    @buttons << 'toggle-seen-button'
  end

  controller :MarkSeen do
    @undo = nil
    @label = 'mark seen'
    @disabled = false
    def click
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
    def click
      broadcast! :toggleComments, (@label == 'show')
      @label = (@label == 'show' ? 'hide' : 'show')
    end
  end

  # controller for the shepherd pages
  controller :Shepherd do
    @agenda = Agenda.get()
    @name = $routeParams.name
    $scope.layout title: "Shepherded By #{@name}", 
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
    def save
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
    @baseline = @report = @item.report

    if @post_button_text == 'edit report'
      @message = "Edit #{@item.title} Report"
    else
      @message = "Post #{@item.title} Report"
    end

    reflow_filter = filter(:reflow)
    def reflow
      @report = reflow_filter(@report)
    end

    def save
      data = {attach: @item.attach, report: @report, agenda: Data.get('agenda'),
        message: @message}
 
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

  controller :SpecialOrder do
    @title = ''

    def save
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
    def click
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
    @pending = Pending.get()

    def label
      if @pending.approved.include? @item.attach
        return 'unapprove'
      else
        return 'approve'
      end
    end

    def click
      data = {attach: @item.attach, request: self.label(),
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
    if not @minutes
      if @item.title == 'Roll Call'
        @minutes = @item.text
        @minutes.sub! /^ASF members[\s\S]*?\n\n/m, '' # remove leading paragraph
        @minutes.gsub! /\s*\(expected.*?\)/, '' # remove (expected...)
      elsif @item.title == 'Action Items'
        @minutes = @item.text
      end
    end
  end

  # Secretary timestamp for Call to Order and Adjournment
  controller :Timestamp do
  end

  # controller for the section pages
  controller :Section do
    @forms = []
    @agenda = Agenda.get()
    @initials = Data.get('initials')

    # fetch section from the route parameters
    section = $routeParams.section || $routeParams.qsection

    # find agenda item, add relevant buttons
    watch 'agenda.update' do
      item = @agenda.find {|item| item.href == section}
      if item
        @buttons.clear()
        @forms.clear()

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

        unless item.comments === undefined
          @buttons << 'comment-button'
          @forms << '../partials/comment.html'
        end

        if item.attach =~ /^(\d|[A-Z]+)$/
          if item.missing
            $rootScope.post_button_text = 'post report'
            @post_form_title = 'Post report'
          else
            $rootScope.post_button_text = 'edit report'
            @post_form_title = 'Edit report'
          end
          @buttons << 'post-button'
          @forms << '../partials/post.html'
        end

        if item.report or item.text
          if @mode==:director and item.approved
            @buttons << 'approve-button' unless item.approved.include? @initials
          end
        end

        if @mode==:secretary
          if ['Call to order', 'Adjournment'].include? item.title
            @buttons << 'timestamp-button'
          else
            @buttons << 'minute-button'
            @forms << '../partials/minute.html'
          end
        end
      else
        $scope.layout item: {title: 'not found'}
      end
    end

    @pending = Pending.get()
    watch 'pending.update + agenda.update' do
      @comment = @pending.comments[@item.attach]
      $rootScope.comment_label =
        (@comment && @comment.length > 0 ? 'edit comment' : 'add comment')
    end
  end
end
