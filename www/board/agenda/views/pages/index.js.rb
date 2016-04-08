#
# Overall Agenda page: simple table with one row for each item in the index
#

class Index < React
  def render
    _header do
      _h1 'ASF Board Agenda'
    end

    _table.table_bordered do
      _thead do
        _th 'Attach'
        _th 'Title'
        _th 'Owner'
        _th 'Shepherd'
      end

      _tbody Agenda.index do |row|
        _tr class: row.color do
          _td row.attach
          _td { _Link text: row.title, href: row.href }
          _td row.owner
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
