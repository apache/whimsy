#!/usr/bin/ruby

module Angular::AsfRoster
  use :AsfRosterServices

  $locationProvider.html5Mode(true).hashPrefix('!')

  case $routeProvider
  when '/'
    templateUrl 'partials/index.html'
    controller :Index

  when '/committer/'
    templateUrl 'partials/committers.html'
    controller :Committers

  when '/committer/:name'
    templateUrl 'partials/committer.html'
    controller :Committer

  when '/committee/'
    templateUrl 'partials/committees.html'
    controller :PMCs

  when '/committee/:name'
    templateUrl 'partials/committee.html'
    controller :PMC

  when '/group/'
    templateUrl 'partials/groups.html'
    controller :Groups

  when '/group/:name'
    templateUrl 'partials/group.html'
    controller :Group

  else
    redirectTo '/'
  end

  controller :Index do
    def size(hash)
      return hash.keys().length || ''
    end
  end

  controller :Layout do
    LDAP.get()
    AUTH.get()
    @groups = Roster::GROUPS
    @committers = Roster::COMMITTERS
    @pmcs = Roster::PMCS
    @members = Roster::MEMBERS
    @info = INFO.get()
    @search = {committer: ''}

    $rootScope.title = 'ASF Roster'

    watch document.querySelector('main') do |value|
      @user = value.attributes['data-availid'].value if value
    end

    def is_empty(hash)
      return Object.keys(hash).length == 0
    end
  end

  controller :Committers do
    @search.committer = $location.search().q
    $rootScope.title = 'ASF Committers'
  end

  controller :PMCs do
    $rootScope.title = 'ASF PMCs'
    watch @groups['pmc-chairs'] do |value|
      @pmc_chairs = value.memberUid if value
    end
  end

  controller :PMCLine do
    @class = 'issue'
    @status = ''
    if not @pmc.chair and INFO.get().keys().length > 0
      @status = 'Not in committee-info.txt'
    elsif not @pmc_chairs.include? @pmc.chair.uid
      @status = 'Not in pmc-chairs LDAP service'
    else
      @class = ''
    end
  end

  controller :Groups do
    $rootScope.title = 'ASF Groups'
  end

  controller :PMC do
    @name = $rootScope.title = $routeParams.name

    watch INFO.get(@name) do |value|
      @info = value || {memberUid: []}
    end

    watch @pmcs[@name] do |value|
      @pmc = value || {memberUid: []}
    end
  end

  controller :PMCMember do
    @class = 'issue'

    if not @person
      @status = 'not found'
    elsif not (@pmc.memberUid.include? @person.uid or @pmc.memberUid.empty?)
      @status = 'not in LDAP'
      @hint = "modify_committee.pl #{@name} --add #{@person.uid}"
    elsif not (@info.memberUid.include? @person.uid or @info.memberUid.empty?)
      @status = 'not in committee_info.txt'
      @hint = "modify_committee.pl mesos --rm #{@person.uid}"
    elsif @pmc.group and not @pmc.group.memberUid.include? @person.uid
      @status = 'not in committer list'
      @hint = "modify_unix_group.pl #{@name} --add #{@person.uid}"
    elsif @person.uid == @info.chair
      @status = 'chair'
      @class = 'chair'
    else
      @class = ''
      @status = ''
    end
  end

  controller :Group do
    @name = $rootScope.title = $routeParams.name
    watch @groups[@name] do |value|
      @group = value || {memberUid: []}
    end
  end

  controller :Committer do
    @uid = $rootScope.title = $routeParams.name
    @my_committer = []
    @my_groups = []
    watch Committer.find(@uid) do |value|
      @committer = value
    end
  end

  filter :committer_match do |committers, text|
    results = []
    text = text.downcase()

    if text.include? ' '
      words = text.split(/\s+/)
      for id in committers
        committer = committers[id]
        cn = committer.cn.downcase()
        if words.all? {|word| cn.include? word}
          results << committer
        end
      end
    else
      for id in committers
        committer = committers[id]
        if committer.cn.downcase().include? text
          results << committer
        elsif committer.uid.include? text
          results << committer
        elsif committer.mail and 
          committer.mail.any? {|email| email.include? text}
          results << committer
        elsif committer["asf-altEmail"] and
          committer["asf-altEmail"].any? {|email| email.include? text}
          results << committer
        end
      end
    end

    results.sort! {|a,b| return a.uid < b.uid ? -1 : +1}

    return results
  end

  directive :main do
    restrict :E
    def link(scope, element, attributes)
      window.scrollTo(0,0)
      element.find('*[autofocus]').focus()
    end
  end

  directive :asfId do
    def link(scope, element, attributes)
      observe attributes.asfId do |value|
        element.addClass 'member' if @members.include? value
      end
    end
  end
end
