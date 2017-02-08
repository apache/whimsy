#
# FY22 budget worksheet
#
_html do
  _title 'ASF Board Agenda - FY22'
  _meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
  _style %{
    .table thead tr th {text-align: right}
    .table tbody tr td.num {text-align: right}
    .table tbody tr td.indented {padding-left: 2em}
    .table tbody tr td input {align: right; text-align: right}
  }

  _h2 'FY22 budget worksheet'

  _p "Instructions: change an input field and press the tab key."

  _table.table.table_striped do
    _thead do
      _tr do
        _th
        _th 'FY17'
        _th 'Min FY22'
        _th 'FY22'
        _th 'Max FY22'
        _th 'Budget'
      end
    end

    _tbody do
      _tr do
        _td 'Income', colspan: 6
      end

      _tr do
        _td.indented 'Total Public Donations'
        _td.num 89
        _td.num 90
        _td.num 110
        _td.num 135
        _td.num { _input.donations! }
      end

      _tr do
        _td.indented 'Total Sponsorship'
        _td.num 968
        _td.num 900
        _td.num '1,000'
        _td.num '1,100'
        _td.num { _input.sponsorship! }
      end

      _tr do
        _td.indented 'Total Programs'
        _td.num 28
        _td.num 28
        _td.num 28
        _td.num 28
        _td.num 28
      end

      _tr do
        _td.indented 'Interest Income'
        _td.num 4
        _td.num 4
        _td.num 4
        _td.num 4
        _td.num 4
      end

      _tr do
        _td
        _td.num '----'
        _td.num '----'
        _td.num '----'
        _td.num '----'
        _td.num '----'
      end

      _tr do
        _td.indented 'Total Income'
        _td.num '1,089'
        _td.num '1,022'
        _td.num '1,142'
        _td.num '1,267'
        _td.num.income!
      end

      _tr do
        _td colspan: 6
      end

      _tr do
        _td 'Expense', colspan: 6
      end

      _tr do
        _td.indented 'Infrastructure'
        _td.num 723
        _td.num 868
        _td.num 868
        _td.num 868
        _td.num {_input.infrastructure!}
      end

      _tr do
        _td.indented 'Program Expenses'
        _td.num 27
        _td.num 27
        _td.num 27
        _td.num 27
        _td.num 27
      end

      _tr do
        _td.indented 'Publicity'
        _td.num 141
        _td.num 273
        _td.num 352
        _td.num 540
        _td.num { _input.publicity! }
      end

      _tr do
        _td.indented 'Brand Management'
        _td.num 84
        _td.num 92
        _td.num 141
        _td.num 218
        _td.num { _input.brandManagement! }
      end

      _tr do
        _td.indented 'Conferences'
        _td.num 12
        _td.num 12
        _td.num 12
        _td.num 12
        _td.num { _input.conferences! }
      end

      _tr do
        _td.indented 'Travel Assistance'
        _td.num 62
        _td.num 0
        _td.num 79
        _td.num 150
        _td.num { _input.travelAssistance! }
      end

      _tr do
        _td.indented 'Treasury'
        _td.num 48
        _td.num 49
        _td.num 51
        _td.num 61
        _td.num { _input.treasury! }
      end

      _tr do
        _td.indented 'Fundraising'
        _td.num 8
        _td.num 18
        _td.num 23
        _td.num 23
        _td.num { _input.fundraising! }
      end

      _tr do
        _td.indented 'General & Administrative'
        _td.num 114
        _td.num 50
        _td.num 139
        _td.num 300
        _td.num { _input.generalAndAdministrative! }
      end

      _tr do
        _td
        _td.num '----'
        _td.num '----'
        _td.num '----'
        _td.num '----'
        _td.num '----'
      end

      _tr do
        _td.indented 'Total Expense'
        _td.num '1,219'
        _td.num '1,390'
        _td.num '1,693'
        _td.num '2,199'
        _td.num.expense!
      end

      _tr do
        _td colspan: 6
      end

      _tr do
        _td 'Net'
        _td.num '-130'
        _td.num '-369'
        _td.num '-552'
        _td.num '-993'
        _td.num.net!
      end

      _tr do
        _td colspan: 6
      end

      _tr do
        _td 'Cash'
        _td.num '1,656'
        _td.num 290
        _td.num -259
        _td.num -1403
        _td.num.cash!
      end
    end
  end

  _p "Units are in thousands of dollars US."

  _script %q{
    values = {
      donations: 110,
      sponsorship: 1000,
      infrastructure: 868,
      publicity: 352,
      brandManagement: 141,
      conferences: 12,
      travelAssistance: 79,
      treasury: 51,
      fundraising: 23,
      generalAndAdministrative: 139,
    }

    function update() {
      values.income = values.donations + values.sponsorship + 28 + 4;

      values.expense = values.infrastructure + 27 + values.publicity + 
        values.brandManagement + values.conferences + values.travelAssistance +
        values.treasury + values.fundraising + values.generalAndAdministrative;

      values.net = values.income - values.expense;

      values.cash = 1656 - 2*130 + 3*values.net;

      for (var name in values) {
        var element = document.getElementById(name);
        if (element.tagName == 'INPUT') {
          element.value = values[name].toLocaleString()
        } else {
          element.textContent = values[name].toLocaleString()
        }
      }
    }

    $('input').blur(function(event) {
      values[event.target.id] = parseInt(event.target.value.replace(/\D/g, ''));
      update();
    });

    update();
  }
end
