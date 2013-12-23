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
  def resize(headers)
    if headers
      ~window.resize do
        ~'body'.css(
          paddingTop:    ~('header.navbar').css(:height),
          paddingBottom: ~('footer.navbar').css(:height)
        )
      end
    else
      ~window.resize do
        ~'body'.css(paddingTop: 0, paddingBottom: 0)
      end
    end

    ~window.trigger(:resize)
    window.scrollTo(0,0)
  end

  # controller for the index page
  controller :Index do
    $scope.agenda = Agenda.get()
    $scope.agenda_file = Agenda.filename()

    resize(false)
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

    resize(false)
  end

  # controller for the section pages
  controller :Section do
    $scope.agenda = Agenda.get()
    $scope.toc = Agenda.index()

    # fetch section from the route parameters
    section = $routeParams.section

    # find agenda item, update scope properties to include item properties
    $scope.title = 'not found'
    $scope.item = {}
    Agenda.forEach do |item|
      if item.title == section
        $scope.item = item
        for prop in item
          $scope[prop] = item[prop]
        end
      end
    end

    # refresh agenda
    def $scope.refresh
      Agenda.refresh()
    end

    resize(true)
  end

  # link traversal via left/right keys
  ~document.keydown do |event|
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
