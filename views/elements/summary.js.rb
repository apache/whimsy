#
# Data/summary/statistics.
#

class Summary < React
  def render
    _table.table_bordered do
      count = 0
      link = nil
      Agenda.index.each do |item| 
        if item.attach =~ /^[A-Z]+$/
          count += 1
          link ||= item.href
        end
      end

      _tr.available do
        _td count 
        _td {_Link href: link, text: 'committee reports'}
      end

      count = 0
      link = nil
      Agenda.index.each do |item| 
        if item.attach =~ /^7[A-Z]+$/
          count += 1
          link ||= item.href
        end
      end

      _tr.available do
        _td count 
        _td {_Link href: link, text: 'special orders'}
      end

      count = 0
      Agenda.index.each {|item| count += 1 if item.color == 'ready'}

      _tr.ready do
        _td count
        _td {_Link href: 'queue', text: 'awaiting preapprovals'}
      end

      count = 0
      Agenda.index.each {|item| count += 1 if item.flagged_by}

      _tr.commented do
        _td count
        _td {_Link href: 'flagged', text: 'flagged reports'}
      end

      count = 0
      Agenda.index.each {|item| count += 1 if item.missing}

      _tr.missing do
        _td count
        _td {_Link href: 'missing', text: 'missing reports'}
      end
    end
  end
end
