#!/usr/bin/ruby

module Angular::AsfRoster
  use :AsfRosterServices

  $locationProvider.html5Mode(true).hashPrefix('!')

  case $routeProvider
  when '/committer/'
    templateUrl 'partials/committers.html'
    controller :Committers

  when '/committer/:name'
    templateUrl 'partials/committer.html'
    controller :Committer

  when '/pmc/:name'
    templateUrl 'partials/pmc.html'
    controller :PMC

  else
    redirectTo '/'
  end

  controller :Layout do
    @groups = LDAP.groups()
    @committers = LDAP.committers()
    @pmcs = LDAP.pmcs()
    @members = LDAP.members()
  end

  controller :Committers do
  end

  controller :Committer do
    @uid = $routeParams.name
    @my_groups = []
    watch(@committers[@uid]) do |value| 
      @committer = value
      @member = value and @members.include? value.uid

      @my_pmcs = []
      for pmc in @pmcs
        @my_pmcs << pmc if @pmcs[pmc].memberUid.include? value.uid
      end

      @my_groups = []
      for group in @groups
        next if @my_pmcs.include? group
        next if %w(member committers).include? group
        @my_groups << group if @groups[group].memberUid.include? value.uid
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
