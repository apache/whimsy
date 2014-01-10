#!/usr/bin/ruby

# main application, consisting of a router and a number of controllers

module Angular::AsfBoardAgenda
  use :AsfBoardServices, :AsfBoardFilters

  # route request based on fragment identifier
  case $routeProvider
  when '/'
    templateUrl 'partials/index.html'
    controller :Index

  when '/help'
    templateUrl 'partials/help.html'
    controller :Help

  when '/queue'
    templateUrl 'partials/pending.html'
    controller :PendingItems

  when '/comments'
    templateUrl 'partials/comments.html'
    controller :Comments

  when '/queue/:qsection'
    templateUrl 'partials/section.html'
    controller :Section

  when '/shepherd/:name'
    templateUrl 'partials/shepherd.html'
    controller :Shepherd

  when '/:section'
    templateUrl 'partials/section.html'
    controller :Section

  else
    redirectTo '/'
  end

  # resize body, leaving room for headers
  def resize_window
    ~window.resize do
      ~'main'.css(
        marginTop:    ~('header.navbar').css(:height),
        marginBottom: ~('footer.navbar').css(:height)
      )
    end

    ~window.trigger(:resize)
    window.scrollTo(0,0)
  end

  controller :Layout do
    @toc = Agenda.index()
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

      @director = true if Data.get('initials')
      @firstname = Data.get('firstname')

      resize_window()
    end

     # link traversal via left/right keys
     ~document.keydown do |event|
       return unless ~('.modal-open').empty?
       if event.keyCode == 37 # '<-'
         ~"a[rel='prev']".click
         return false
       elsif event.keyCode == 39 # '->'
         ~"a[rel='next']".click
         return false
       elsif event.keyCode == 'C'.ord
         ~"#comments"[0].scrollIntoView()
         return false
       elsif event.keyCode == 'I'.ord
         ~"#info".click
         return false
       elsif event.keyCode == 'N'.ord
         ~"#nav".click
         return false
       elsif event.keyCode == 'A'.ord
         ~"#agenda".click
         return false
       elsif event.keyCode == 'Q'.ord
         ~"#queue".click
         return false
       elsif event.keyCode == 'S'.ord
         ~"#shepherd".click
         return false
       elsif event.shiftKey and event.keyCode == 191 # "?"
         ~"#help".click
         return false
       elsif event.keyCode == 'R'.ord
         ~'#clock'.show
         Pending.get()
         data = {agenda: Data.get('agenda')}
         $http.post('json/refresh', data).success do |response|
           Agenda.put response
           $route.reload()
           ~'#clock'.hide
         end
         return false
        end
    end
  end

  # controller for the index page
  controller :Index do
    @agenda = Agenda.get()
    @agenda_file = Data.get('agenda')
     
    title = @agenda_file[/\d+_\d+_\d+/].gsub(/_/,'-')

    agendas = ~'#agendas li'.to_a.map {|li| return li.textContent.trim()}
    index = agendas.indexOf(@agenda_file)
    agendas = agendas.map do |text|
      return {href: text, title: text[/\d+_\d+_\d+/].gsub(/_/,'-')}
    end

    help = {href: '#/help', title: 'Help'}
    $scope.layout title: title, next: agendas[index+1] || help, 
      prev: agendas[index-1] || help
    @buttons.push 'refresh-button'
  end

  # controller for the help page
  controller :Help do
    $scope.layout title: 'Help'
  end

  # controller for the pending pages
  controller :PendingItems do
    @agenda = Agenda.get()
    @pending = Pending.get()
    firstname = Data.get('firstname')

    $scope.layout title: 'Queued approvals and comments',
      prev: ({title: 'Shepherd', href: "#/shepherd/#{firstname}"} if firstname),
      next: {title: 'Comments', href: '#/comments'}

    @q_approvals = []
    @q_ready = []
    @q_comments = []
    watch 'pending.update + agenda.update' do
      @q_approvals.clear!
      @agenda.forEach do |item|
        @q_approvals.push item if @pending.approved.include? item.attach
      end

      comments = @pending.comments
      @q_comments.clear!
      @agenda.forEach do |item|
        if comments[item.attach]
          item.comment = comments[item.attach]
          @q_comments.push item
        end
      end

      @q_ready.clear!
      Agenda.ready().forEach do |item|
        @q_ready.push item unless @q_approvals.include? item
      end
    end

    watch 'q_comments.length + q_approvals.length' do |after, before|
      if after > 0 and !@buttons.include? 'commit-button'
        @buttons.push 'commit-button' 
      end

      message = []

      if @q_approvals.length > 0 and @q_approvals.length <= 6
        message.push "Approve #{
          @q_approvals.map {|item| return item.title}.join(', ')}"
      elsif @q_approvals.length > 1
        message.push "Approve #{ @q_approvals.length} reports"
      end

      if @q_comments.length > 0 and @q_comments.length <= 6
        message.push "Comment on #{
          @q_comments.map {|item| return item.title}.join(', ')}"
      elsif @q_comments.length > 1
        message.push "Comment on #{ @q_comments.length} reports"
      end

      @commit_message = message.join("\n")
    end
  end

  controller :Commit do
    def commit
      data = {message: @commit_message}

      $http.post('json/commit', data).success { |response|
        Agenda.put response.agenda
        Pending.put response.pending
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception 
      }.finally {
        ~'#commit-form'.modal(:hide)
      }
    end
  end

  # controller for the comments pages
  controller :Comments do
    initials = Data.get('initials')
    $scope.layout title: "Comments",
      prev: ({title: 'Queue', href: '#/queue'} if initials)
    @agenda = Agenda.get()
    @pending = Pending.get()
    @toggle = false
    show = filter(:show)

    watch 'agenda.update + pending.update' do
      $rootScope.unseen_comments =
        @agenda.any? { |item| return show(item, seen: @pending.seen) }
      $rootScope.seen_comments = !Object.keys(@pending.seen).empty?
    end
    @buttons.push 'mark-seen-button'

    @buttons.push 'toggle-seen-button'
    on :toggleComments do |event, state| 
      @toggle = state
    end
  end

  controller :MarkSeen do
    @disabled = false
    def click
      @disabled = true

      # gather up the comments
      seen = {}
      Agenda.get().forEach do |item|
        seen[item.attach] = item.comments if item.comments
      end

      data = { seen: seen, agenda: Data.get('agenda') }

      $http.post('json/markseen', data).success { |response|
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
      next: {title: 'Queue', href: '#/queue'}

    watch 'agenda.update' do
      @agenda.forEach do |item|
        if item.title == 'Review Outstanding Action Items'
          @actions = item
          @assigned = item.text.split("\n\n").filter do |item|
            return item =~ /^\* *#{$routeParams.name}/m
          end
        end
    end
    end
  end

  controller :Comment do
    def save
      data = {attach: @item.attach, initials: @initials, comment: @comment,
        agenda: Data.get('agenda')}

      $http.post('json/comment', data).success { |response|
        Pending.put response
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception 
      }.finally {
        ~'#comment-form'.modal(:hide)
      }
    end
  end

  controller :Refresh do
    @disabled = false
    def click
      data = {agenda: Data.get('agenda')}

      @disabled = true
      $http.post('json/refresh', data).success { |response|
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

      $http.post('json/approve', data).success { |response|
        Pending.put response
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception 
      }
    end
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
      $scope.layout item: {title: 'not found'}
      @agenda.forEach do |item|
        if item.title == section

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
            @buttons.push 'comment-button'
            @forms.push 'partials/comment.html'
          end

          if item.approved and @initials and !item.approved.include? @initials
            if item.report or item.text
              @buttons.push 'approve-button'
            end
          end
        end
      end
    end

    @pending = Pending.get()
    watch 'pending.update' do
      @comment = @pending.comments[@item.attach]
    end
  end
end
