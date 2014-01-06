#!/usr/bin/ruby

# main application, consisting of a router and a number of controllers

module Angular::AsfBoardAgenda
  use :AsfBoardServices, :AsfBoardFilters

  # route request based on fragment identifier
  case $routeProvider
  when '/'
    templateUrl 'partials/index.html'
    controller :Index

  when '/queue'
    templateUrl 'partials/pending.html'
    controller :PendingItems

  when '/shepherd/:name'
    templateUrl 'partials/shepherd.html'
    controller :Shepherd

  when '/:section'
    templateUrl 'partials/section.html'
    controller :Section

  else
    redirectTo '/'
  end

  # resize body, optionally leave room for headers
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
      if vars.item != undefined
        @item = vars.item
        @next = vars.item.next
        @prev = vars.item.prev
        @title = vars.item.title
      else
        @item = {}
        @next = nil
        @prev = nil
        @title = ''
      end

      @title = vars.title if vars.title != undefined
      @next = vars.next if vars.next != undefined
      @prev = vars.prev if vars.prev != undefined

      @director = true if Data.get('initials')
      @firstname = Data.get('firstname')
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

    Agenda.forEach {}
    $scope.layout title: title, next: agendas[index+1], prev: agendas[index-1]
    @buttons.push 'refresh-button'

    resize_window()
  end

  # controller for the pending pages
  controller :PendingItems do
    @agenda = Agenda.get()
    @pending = Pending.get()
    $scope.layout title: 'Queued approvals and comments'
    resize_window()
    initials = Data.get('initials')

    @q_approvals = []
    @q_ready = []
    watch 'pending.approved.length + agenda.length' do
      @q_approvals.clear!
      @q_ready.clear!
      @agenda.forEach do |item|
        if @pending.approved.include? item.attach
          @q_approvals.push item 
        elsif initials
          next unless item.approved
          next if item.approved.include? initials
          next unless item.report or item.text
          @q_ready.push item
        end
      end
    end

    @q_comments = []
    watch 'pending.comments.length + agenda.length' do
      @q_comments.clear!
      @agenda.forEach do |item|
        if @pending.comments[item.attach]
          item.comment = @pending.comments[item.attach]
          @q_comments.push item
        end
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

  # controller for the shepherd pages
  controller :Shepherd do
    @agenda = Agenda.get()
    @name = $routeParams.name
    $scope.layout title: "Shepherded By #{@name}"

    Agenda.forEach do |item|
      if item.title == 'Review Outstanding Action Items'
        @actions = item
        @assigned = item.text.split("\n\n").filter do |item|
          return item =~ /^\* *#{$routeParams.name}/m
        end
      end
    end

    resize_window()
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
    @agenda = Data.get('agenda')
    @initials = Data.get('initials')

    # fetch section from the route parameters
    section = $routeParams.section

    # find agenda item, update scope properties to include item properties
    $scope.layout item: {title: 'not found'}
    Agenda.forEach do |item|
      if item.title == section
        $scope.layout item: item
        if item.comments != undefined
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

    @pending = Pending.get()
    watch 'pending.comments.length' do
      @comment = @pending.comments[@item.attach]
    end

    # refresh agenda
    def refresh
      Agenda.refresh()
    end

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
     elsif event.keyCode == 'C'.ord and ~'#comments'.length == 1
       ~"#comments"[0].scrollIntoView()
       return false
     elsif event.keyCode == 'I'.ord and ~'#info'.length == 1
       ~"#info".click
       return false
     elsif event.keyCode == 'N'.ord and ~'#nav'.length == 1
       ~"#nav".click
       return false
     elsif event.keyCode == 'A'.ord and ~'#agenda'.length == 1
       ~"#agenda".click
       return false
     elsif event.keyCode == 'Q'.ord and ~'#queue'.length == 1
       ~"#queue".click
       return false
     elsif event.keyCode == 'S'.ord and ~'#shepherd'.length == 1
       ~"#shepherd".click
       return false
     end
  end
end
