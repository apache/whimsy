#!/usr/bin/ruby

# main application, consisting of a router and a number of controllers

module Angular::AsfBoardAgenda
  use :AsfBoardServices, :AsfBoardFilters

  # route request based on fragment identifier
  case $routeProvider
  when '/'
    templateUrl 'partials/index.html'
    controller :Index

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
    end
  end

  # controller for the index page
  controller :Index do
    @agenda = Agenda.get()
    @agenda_file = Agenda.filename()
     
    title = @agenda_file[/\d+_\d+_\d+/].gsub(/_/,'-')

    agendas = ~'#agendas li'.to_a.map {|li| return li.textContent.trim()}
    index = agendas.indexOf(@agenda_file)
    agendas = agendas.map do |text|
      return {href: text, title: text[/\d+_\d+_\d+/].gsub(/_/,'-')}
    end

    $scope.layout title: title, next: agendas[index+1], prev: agendas[index-1]

    resize_window()
  end

  # controller for the shepherd pages
  controller :Shepherd do
    @agenda = Agenda.get()
    @name = $routeParams.name

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
      data = {attach: @item.attach, initials: @initials, comment: @comment}

      $http.post('json/comment', data).success { |response|
        Pending.put response
      }.error { |data|
        $log.error data.exception + "\n" + data.backtrace.join("\n")
        alert data.exception 
      }.finally {
        ~'#comment'.modal(:hide)
      }
    end
  end

  # controller for the section pages
  controller :Section do
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
          @buttons.push label: 'comment', target: '#comment',
            include: 'partials/comment.html'
        end
      end
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
     end
  end
end
