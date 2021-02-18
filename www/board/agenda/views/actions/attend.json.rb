#
# Indicate intention to attend / regrets for meeting
#

if @action == 'regrets'
  message = "Regrets for the meeting."
else
  message = "I plan to attend the meeting."
end

Agenda.update(@agenda, message) do |agenda|

  rollcall = agenda[/^ \d\. Roll Call.*?\n \d\./m]
  rollcall.gsub!(/ +\n/, '')

  directors = rollcall[/^ +Directors.*?:\n\n.*?\n\n +Directors.*?:\n\n.*?\n\n/m]
  officers = rollcall[/^ +Executive.*?:\n\n.*?\n\n +Executive.*?:\n\n.*?\n\n/m]
  guests = rollcall[/^ +Guests.*?:\n\n.*?\n\n/m]

  if directors.include? @name

    updated = directors.sub /^ .*#{Regexp.escape(@name)}.*?\n/, ''

    if @action == 'regrets'
      updated[/Absent:\n\n.*?\n()\n/m, 1] = "        #{@name}\n"
      updated.sub! /:\n\n +none\n/, ":\n\n"
      updated.sub! /Present:\n\n\n/, "Present:\n\n        none\n\n"
    else
      updated[/Present:\n\n.*?\n()\n/m, 1] = "        #{@name}\n"
      updated.sub! /Absent:\n\n\n/, "Absent:\n\n        none\n\n"

      # sort Directors
      updated.sub!(/Present:\n\n(.*?)\n\n/m) do |match|
        before=$1
        after=before.split("\n").sort_by {|name| name.split.rotate(-1)}
        match.sub(before, after.join("\n"))
      end
    end

    rollcall.sub! directors, updated

  elsif officers.include? @name

    updated = officers.sub /^ .*#{Regexp.escape(@name)}.*?\n/, ''

    if @action == 'regrets'
      updated[/Absent:\n\n.*?\n()\n/m, 1] = "        #{@name}\n"
      updated.sub! /:\n\n +none\n/, ":\n\n"
      updated.sub! /Present:\n\n\n/, "Present:\n\n        none\n\n"
    else
      updated[/Present:\n\n.*?\n()\n/m, 1] = "        #{@name}\n"
      updated.sub! /Absent:\n\n\n/, "Absent:\n\n        none\n\n"
    end

    rollcall.sub! officers, updated

  elsif @action == 'regrets'

    updated = guests.sub /^ .*#{Regexp.escape(@name)}.*?\n/, ''
    updated.sub! /:\n\n\n/, ":\n\n        none\n"

    rollcall.sub! guests, updated

  elsif not guests.include? @name

    updated = guests.sub /\n\Z/, "\n        #{@name}\n"
    updated.sub! /:\n\n +none\n/, ":\n\n"

    rollcall.sub! guests, updated

  end

  agenda[/^ \d\. Roll Call.*?\n \d\./m] = rollcall

  agenda
end
