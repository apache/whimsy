#
# A two section representation of an agenda item (typically a PMC report),
# where the two sections will show up as two columns on wide enough windows.
#
# The first section contains the item text, with a missing indicator if
# the report isn't present.
#
# The second section contains posted comments, pending comments, and
# action items associated with this agenda item.
#
# Filters may be used to highlight or hypertext link portions of the text.
#

class Report < React
  def render

    # determine what text filters to run
    filters = [hotlink]
    filters << self.localtime if @@item.title == 'Call to order'
    filters << self.names if @@item.people

    _section.flexbox do
      _section do
        _pre.report do
          _p {_em 'Missing'} if @@item.missing
          _Text raw: @@item.text, filters: filters
        end
      end

      _section do
        unless @@item.comments.empty?
          _h3.comments! 'Comments'
          @@item.comments.each do |comment|
            _pre.comment do
              _Text raw: comment, filters: [hotlink]
            end
          end
        end

        if @@item.pending
          _h3.comments! 'Pending Comment'
          _pre.comment "#{Pending.initials}: #{@@item.pending}"
        end

        if @@item.title != 'Action Items' and @@item.actions
          _h3.comments! { _Link text: 'Action Items', href: 'Action-Items' }
          @@item.actions.each do |action|
            _pre.comment action
          end
        end
      end
    end
  end

  # Convert start time to local time on Call to order page
  def localtime(text)
    return text.sub /\n(\s+)(Other Time Zones:.*)/ do |match, spaces, text|
      localtime = Date.new(@@item.timestamp).toLocaleString()
      "\n#{spaces}<span class='hilite'>" +
        "Local Time: #{localtime}</span>#{spaces}#{text}"
    end
  end

  # replace ids with committer links
  def names(text)
    roster = 'https://whimsy.apache.org/roster/committer/'

    for id in @@item.people
      person = @@item.people[id]

      # email addresses in 'Establish' resolutions
      text.gsub! /(\(|&lt;)(#{id})( at |@|\))/ do |m, pre, id, post|
        if person.icla
          "#{pre}<a href='#{roster}#{id}'>#{id}</a>#{post}"
        else
          "#{pre}<a class='missing' href='#{roster}?q=#{person.name}'>" +
            "#{id}</a>#{post}"
        end
      end

      # names
      if person.icla or @@item.title == 'Roll Call'
        text.sub! /#{escapeRegExp(person.name)}/, 
          "<a href='#{roster}#{id}'>#{person.name}</a>"
      end

      # highlight potentially misspelled names
      if person.icla and not person.icla == person.name
        names = person.name.split(/\s+/)
        iclas = person.icla.split(/\s+/)
        ok = false
        ok ||= names.all? {|part| iclas.any? {|icla| icla.include? part}}
        ok ||= iclas.all? {|part| names.any? {|name| name.include? part}}
        if @@item.title =~ /^Establish/ and not ok
          text.gsub! /#{escapeRegExp("#{id}'>#{person.name}")}/,
            "?q=#{encodeURIComponent(person.name)}'>" +
            "<span class='commented'>#{person.name}</span>"
        else
          text.gsub! /#{escapeRegExp(person.name)}/, 
            "<a href='#{roster}#{id}'>#{person.name}</a>"
        end
      end

      # put members names in bold
      if person.member
        text.gsub! /#{escapeRegExp(person.name)}/, "<b>#{person.name}</b>"
      end
    end

    # treat any unmatched names in Roll Call as misspelled
    if @@item.title == 'Roll Call'
      text.gsub! /(\n\s{4})([A-Z].*)/ do |match, space, name|
        "#{space}<a class='commented' href='#{roster}?q=#{name}'>#{name}</a>"
      end
    end

    return text
  end
end
