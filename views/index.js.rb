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
	  _td do
	    _Link text: row.title, href: row.href
	  end
	  _td row.owner
	  _td row.shepherd
	end
      end
    end
  end
end
