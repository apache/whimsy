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
      ~'#main'.css(
        marginTop:    ~('header.navbar').css(:height),
        marginBottom: ~('footer.navbar').css(:height)
      )
    end

    ~window.trigger(:resize)
    window.scrollTo(0,0)
  end

  controller :Layout do
    $scope.toc = Agenda.index()
    $scope.item = {}
    $scope.next = nil
    $scope.prev = nil
    def $scope.layout(vars)
      $scope.buttons = []
      if vars.item != undefined
        $scope.item = vars.item
        $scope.next = vars.item.next
        $scope.prev = vars.item.prev
        $scope.title = vars.item.title
      else
        $scope.item = {}
        $scope.next = nil
        $scope.prev = nil
        $scope.title = ''
      end

      $scope.title = vars.title if vars.title != undefined
      $scope.next = vars.next if vars.next != undefined
      $scope.prev = vars.prev if vars.prev != undefined
    end
  end

  # controller for the index page
  controller :Index do
    $scope.agenda = Agenda.get()
    $scope.agenda_file = Agenda.filename()
     
    title = $scope.agenda_file.match(/\d+_\d+_\d+/)[0].gsub(/_/,'-')

    agendas = ~'#agendas li'.map {|i,li| return li.textContent.trim()}
    index = agendas.toArray().indexOf($scope.agenda_file)
    agendas = agendas.map do |i,text|
      title = text.match(/\d+_\d+_\d+/)[0].gsub(/_/,'-')
      return {title: title, href: text}
    end

    $scope.layout title: title, next: agendas[index+1], prev: agendas[index-1]

    resize_window()
  end

  # controller for the shepherd pages
  controller :Shepherd do
    $scope.agenda = Agenda.get()
    $scope.name = $routeParams.name

    Agenda.forEach do |item|
      if item.title == 'Review Outstanding Action Items'
        $scope.actions = item
        $scope.assigned = item.text.split("\n\n").filter do |item|
          return item =~ /^\* *#{$routeParams.name}/m
        end
      end
    end

    resize_window()
  end

  # controller for the section pages
  controller :Section do
    $scope.agenda = Agenda.get()

    $scope.initials = 'sr'

    # fetch section from the route parameters
    section = $routeParams.section

    # find agenda item, update scope properties to include item properties
    $scope.layout item: {title: 'not found'}
    Agenda.forEach do |item|
      if item.title == section
        $scope.layout item: item
        if item.comments != undefined
          $scope.buttons.push label: 'comment', target: '#comment',
            include: 'partials/comment.html'
        end
      end
    end

    # refresh agenda
    def $scope.refresh
      Agenda.refresh()
    end

    resize_window()
  end

  # link traversal via left/right keys
  ~document.keydown do |event|
     return if ~('.modal-open').length > 0
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
