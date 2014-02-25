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
      length = hash.keys().length
      if length > 0
        return length
      else
        return ''
      end
    end
  end

  controller :Layout do
    @groups = Merge.groups()
    @committers = LDAP.committers()
    @pmcs = LDAP.pmcs()
    @members = LDAP.members()
    @info = INFO.get()
    @services = LDAP.services()
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
    watch @groups[@name] || LDAP.services()[@name] do |group|
      if group and group.memberUid
        group.members ||= []
        group.members.clear()
        group.memberUid.each do |uid|
          person = @committers[uid]
          group.members << person if person
        end
        @group = group
      end
    end
  end

  controller :Committer do
    @uid = $routeParams.name
    @my_groups = []
    watch Merge.count() do
      @committer = @committers[@uid]

      @my_committer = []
      console.log @committer
      for pmc in @pmcs
        if @pmcs[pmc].members.include? @committer
          console.log pmc
          @my_pmcs << pmc 
        elsif @pmcs[pmc].committers.include? @committer
          @my_committer << pmc
        end
      end

      @my_groups = []
      for group in @groups
        if @groups[group].memberUid.include? @uid
          @my_groups << @groups[group]
        end
      end
    end
  end

  filter :committer_match do |committers, text|
    results = []
    text = text.toLowerCase()

    if text.include? ' '
      words = text.split(/\s+/)
      for id in committers
        committer = committers[id]
        cn = committer.cn.toLowerCase()
        if words.all? {|word| cn.contains(word)}
          results << committer
        end
      end
    else
      for id in committers
        committer = committers[id]
        if committer.cn.toLowerCase().contains(text)
          results << committer
        elsif committer.uid.contains(text)
          results << committer
        elsif committer.mail and 
          committer.mail.any? {|email| email.contains(text)}
          results << committer
        elsif committer["asf-altEmail"] and
          committer["asf-altEmail"].any? {|email| email.contains(text)}
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
