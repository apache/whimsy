#
# FY22 budget worksheet
#
class FY22 < React
  def initialize
    @budget = {
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

    self.recalc();
  end

  def render
    _style %{
      .table thead tr th {text-align: right}
      .table tbody tr td {text-align: left}
      .table tbody tr td.num {text-align: right}
      .table tbody tr td.indented {padding-left: 2em}
      .table tbody tr td input {align: right; text-align: right}
      .table tbody tr td a {color: blue; text-decoration:underline}
    }

    _p "Instructions: change any input field and press the tab key to see " +
      "new results. Try to make FY22 Budget Net non-negative."

    _table.table.table_sm.table_striped do
      _thead do
        _tr do
          _th
          _th 'FY17'
          _th 'Min FY22'
          _th 'FY22'
          _th 'Max FY22'
          _th 'FY22 Budget'
        end
      end

      _tbody do
        _tr do
          _td 'Income', colspan: 6
        end

        _tr do
          _td.indented do
            _a 'Total Public Donations', href: 'https://s.apache.org/sxYI'
          end
          _td.num 89
          _td.num 90
          _td.num 110
          _td.num 135
          _td.num do 
            _input.donations! onBlur: self.change,
              defaultValue: @budget.donations.toLocaleString()
          end
        end

        _tr do
          _td.indented do
            _a 'Total Sponsorship', href: 'https://s.apache.org/sxYI'
          end
          _td.num 968
          _td.num 900
          _td.num (1_000).toLocaleString()
          _td.num (1_100).toLocaleString()
          _td.num do 
            _input.sponsorship! onBlur: self.change,
              defaultValue: @budget.sponsorship.toLocaleString()
          end
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
          _td.num (1_089).toLocaleString()
          _td.num (1_022).toLocaleString()
          _td.num (1_142).toLocaleString()
          _td.num (1_267).toLocaleString()
          _td.num.income! @budget.income.toLocaleString()
        end

        _tr do
          _td colspan: 6
        end

        _tr do
          _td 'Expense', colspan: 6
        end

        _tr do
          _td.indented do
            _a 'Infrastructure', href: 'https://s.apache.org/Rlse'
          end
          _td.num 723
          _td.num 868
          _td.num 868
          _td.num 868
          _td.num do 
            _input.infrastructure! onBlur: self.change,
              defaultValue: @budget.infrastructure.toLocaleString()
          end
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
          _td.indented do
            _a 'Publicity', href: 'https://s.apache.org/lv76'
          end
          _td.num 141
          _td.num 273
          _td.num 352
          _td.num 540
          _td.num do 
            _input.publicity! onBlur: self.change,
              defaultValue: @budget.publicity.toLocaleString()
          end
        end

        _tr do
          _td.indented do
            _a 'Brand Management', href: 'https://s.apache.org/gXdY'
          end
          _td.num 84
          _td.num 92
          _td.num 141
          _td.num 218
          _td.num do 
            _input.brandManagement! onBlur: self.change,
              defaultValue: @budget.brandManagement.toLocaleString()
          end
        end

        _tr do
          _td.indented 'Conferences'
          _td.num 12
          _td.num 12
          _td.num 12
          _td.num 12
          _td.num do 
            _input.conferences! onBlur: self.change,
              defaultValue: @budget.conferences.toLocaleString()
          end
        end

        _tr do
          _td.indented do
            _a 'Travel Assistance', href: 'https://s.apache.org/4LdI'
          end
          _td.num 62
          _td.num 0
          _td.num 79
          _td.num 150
          _td.num do 
            _input.travelAssistance! onBlur: self.change,
              defaultValue: @budget.travelAssistance.toLocaleString()
          end
        end

        _tr do
          _td.indented do
            _a 'Treasury', href: 'https://s.apache.org/EGiC'
          end
          _td.num 48
          _td.num 49
          _td.num 51
          _td.num 61
          _td.num do 
            _input.treasury! onBlur: self.change,
              defaultValue: @budget.treasury.toLocaleString()
          end
        end

        _tr do
          _td.indented do
            _a 'Fundraising', href: 'https://s.apache.org/sxYI'
          end
          _td.num 8
          _td.num 18
          _td.num 23
          _td.num 23
          _td.num do 
            _input.fundraising! onBlur: self.change,
              defaultValue: @budget.fundraising.toLocaleString()
          end
        end

        _tr do
          _td.indented do
            _a 'General & Administrative', href: 'https://s.apache.org/4LdI'
          end
          _td.num 114
          _td.num 50
          _td.num 139
          _td.num 300
          _td.num do 
            _input.generalAndAdministrative! onBlur: self.change,
              defaultValue: @budget.generalAndAdministrative.toLocaleString()
          end
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
          _td.num (1_219).toLocaleString()
          _td.num (1_390).toLocaleString()
          _td.num (1_693).toLocaleString()
          _td.num (2_199).toLocaleString()
          _td.num.expense! @budget.expense.toLocaleString()
        end

        _tr do
          _td colspan: 6
        end

        _tr do
          _td 'Net'
          _td.num -130
          _td.num -369
          _td.num -552
          _td.num -993
          _td.num.net! @budget.net.toLocaleString(),
            class: (@budget.net < 0 ? 'danger' : 'success')
        end

        _tr do
          _td colspan: 6
        end

        _tr do
          _td 'Cash'
          _td.num (1_656).toLocaleString()
          _td.num 290
          _td.num -259
          _td.num (-1_403).toLocaleString()
          _td.num.cash! @budget.cash.toLocaleString()
        end
      end
    end

    _p "Units are in thousands of dollars US."
  end

  def recalc()
    @budget.income = @budget.donations + @budget.sponsorship + 28 + 4

    @budget.expense = @budget.infrastructure + 27 + @budget.publicity + 
      @budget.brandManagement + @budget.conferences + 
      @budget.travelAssistance + @budget.treasury + @budget.fundraising + 
      @budget.generalAndAdministrative;

    @budget.net = @budget.income - @budget.expense

    @budget.cash = 1656 - 2*130 + 3*@budget.net
  end

  def change(event)
    @budget[event.target.id] = parseInt(event.target.value.gsub(/\D/, '')) || 0
    event.target.value = @budget[event.target.id].toLocaleString()
    self.recalc()
    self.forceUpdate()
  end
end
