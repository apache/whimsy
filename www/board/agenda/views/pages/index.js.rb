#
# Overall Agenda page: simple table with one row for each item in the index
#

class Index < Vue
  def render
    _header do
      _h1 'ASF Board Agenda'
    end

    _table.table_bordered.agenda do
      _thead do
        _th 'Attach'
        _th 'Title'
        _th 'Owner'
        _th 'Shepherd'
      end

      meeting_day = Minutes.started || Agenda.meeting_day
      _tbody Agenda.index do |row|
        _tr class: row.color do
          _td row.attach

          # once meeting has started, link to flagged queue for flagged items
          if meeting_day and row.attach =~ /^(\d+|[A-Z]+)$/ and !row.skippable
            _td { _Link text: row.title, href: 'flagged/' + row.href }
          else
            _td { _Link text: row.title, href: row.href }
          end

          _td row.owner || row.chair_name
          _td do
            if row.shepherd
              _Link text: row.shepherd,
                href: "shepherd/#{row.shepherd.split(' ').first}"
            end
          end
        end
      end
    end
  end
end
