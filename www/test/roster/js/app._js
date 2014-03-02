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
    @groups = Roster::GROUPS
    @committers = Roster::COMMITTERS
    @pmcs = Roster::PMCS
    @members = Roster::MEMBERS
    @info = INFO.get()
  end

  controller :Committers do
  end

  controller :PMCs do
  end

  controller :Groups do
  end

  controller :PMC do
    @name = $routeParams.name

    watch INFO.get(@name) do |value|
      @info = value || {memberUid: []}
    end

    watch @pmcs[@name] do |value|
      @pmc = value || {memberUid: []}
    end

    def status(committer)
      if not committer
        return 'not found'
      elsif not (@pmc.memberUid.include? committer.uid or @pmc.memberUid.empty?)
        return 'not in LDAP'
      elsif not (@info.memberUid.include? committer.uid or @info.memberUid.empty?)
        return 'not in committee_info.txt'
#     elsif @committers and not @committers[committer.uid] == committer
#       return 'not in committer list'
      elsif committer.uid == @info.chair
        return 'chair'
      else
        return ''
      end
    end
  end

  controller :Group do
    @name = $routeParams.name
    watch @groups[@name] do |value|
      @group = value || {memberUid: []}
    end
  end

  controller :Committer do
    @uid = $routeParams.name
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
