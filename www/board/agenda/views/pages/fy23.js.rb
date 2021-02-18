#
# FY23 budget worksheet
#
class FY23 < Vue
  def initialize
    @budget = (Minutes.started && Minutes.get('budget')) || {
      donations: 220,
      sponsorship: 1665,
      infrastructure: 1099,
      publicity: 387,
      brandManagement: 225,
      conferences: 60,
      travelAssistance: 25,
      treasury: 61,
      fundraising: 283,
      generalAndAdministrative: 44,
      chairman: 10,
    }

    if User.role == :secretary or not Minutes.started
      @disabled = false
    else
      @disabled = true
    end
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
      "new results. Try to keep FY23 Budget Cash non-negative."

    _table.table.table_sm.table_striped do
      _thead do
        _tr do
          _th
          _th do
            _a 'FY18', href: 'https://whimsy.apache.org/board/minutes/Budget.html#2017-04-19'
          end
          _th do
            _a 'FY22', href: 'https://whimsy.apache.org/board/minutes/Discussion_Items.html#2017-02-27'
          end
          _th 'FY23 Budget'
          _td
        end
      end

      _tbody do
        _tr do
          _td 'Income', colspan: 4
        end

        _tr do
          _td.indented do
            _a 'Total Public Donations', href: 'https://s.apache.org/zFgy'
          end
          _td.num 111
          _td.num 135
          _td.num do
            _input.donations! onBlur: self.change, disabled: @disabled,
              value: @budget.donations.toLocaleString()
          end
        end

        _tr do
          _td.indented do
            _a 'Total Sponsorship', href: 'https://s.apache.org/zFgy'
          end
          _td.num 1_084.toLocaleString()
          _td.num 1_500.toLocaleString()
          _td.num do
            _input.sponsorship! onBlur: self.change, disabled: @disabled,
              value: @budget.sponsorship.toLocaleString()
          end
        end

        _tr do
          _td.indented 'Total Programs'
          _td.num 28
          _td.num 28
          _td.num 28
        end

        _tr do
          _td.indented 'Interest Income'
          _td.num 4
          _td.num 4
          _td.num 4
        end

        _tr do
          _td
          _td.num '----'
          _td.num '----'
          _td.num '----'
        end

        _tr do
          _td.indented 'Total Income'
          _td.num 1_227.toLocaleString()
          _td.num 1_667.toLocaleString()
          _td.num.income! @budget.income.toLocaleString()
        end

        _tr do
          _td colspan: 4
        end

        _tr do
          _td 'Expense', colspan: 4
        end

        _tr do
          _td.indented do
            _a 'Infrastructure', href: 'https://s.apache.org/Db5J'
          end
          _td.num 818
          _td.num 868
          _td.num do
            _input.infrastructure! onBlur: self.change, disabled: @disabled,
              value: @budget.infrastructure.toLocaleString()
          end
        end

        _tr do
          _td.indented 'Program Expenses'
          _td.num 27
          _td.num 27
          _td.num 27
        end

        _tr do
          _td.indented do
            _a 'Publicity', href: 'https://s.apache.org/OTCg'
          end
          _td.num 182
          _td.num 352
          _td.num do
            _input.publicity! onBlur: self.change, disabled: @disabled,
              value: @budget.publicity.toLocaleString()
          end
        end

        _tr do
          _td.indented do
            _a 'Brand Management', href: 'https://s.apache.org/qHyk'
          end
          _td.num 89
          _td.num 141
          _td.num do
            _input.brandManagement! onBlur: self.change, disabled: @disabled,
              value: @budget.brandManagement.toLocaleString()
          end
        end

        _tr do
          _td.indented do
            _a 'Conferences', href: 'https://s.apache.org/wPGQ'
          end
          _td.num 60
          _td.num 12
          _td.num do
            _input.conferences! onBlur: self.change, disabled: @disabled,
              value: @budget.conferences.toLocaleString()
          end
        end

        _tr do
          _td.indented do
            _a 'Travel Assistance', href: 'https://s.apache.org/22KK'
          end
          _td.num 50
          _td.num 79
          _td.num do
            _input.travelAssistance! onBlur: self.change, disabled: @disabled,
              value: @budget.travelAssistance.toLocaleString()
          end
        end

        _tr do
          _td.indented do
            _a 'Treasury', href: 'https://s.apache.org/zFgy'
          end
          _td.num 49
          _td.num 51
          _td.num do
            _input.treasury! onBlur: self.change, disabled: @disabled,
              value: @budget.treasury.toLocaleString()
          end
        end

        _tr do
          _td.indented do
            _a 'Fundraising', href: 'https://s.apache.org/7kuk'
          end
          _td.num 46
          _td.num 53
          _td.num do
            _input.fundraising! onBlur: self.change, disabled: @disabled,
              value: @budget.fundraising.toLocaleString()
          end
        end

        _tr do
          _td.indented do
            _a 'General & Administrative', href: 'https://s.apache.org/4LdI'
          end
          _td.num 118
          _td.num 139
          _td.num do
            _input.generalAndAdministrative! onBlur: self.change,
              disabled: @disabled,
              value: @budget.generalAndAdministrative.toLocaleString()
          end
        end

        _tr do
          _td.indented do
            _ "Board Chair's Discretionary"
          end
          _td.num 10
          _td.num 0
          _td.num do
            _input.generalAndAdministrative! onBlur: self.change,
              disabled: @disabled,
              value: @budget.chairman.toLocaleString()
          end
        end

        _tr do
          _td
          _td.num '----'
          _td.num '----'
          _td.num '----'
        end

        _tr do
          _td.indented 'Total Expense'
          _td.num 1_418.toLocaleString()
          _td.num 1_722.toLocaleString()
          _td.num.expense! @budget.expense.toLocaleString()
        end

        _tr do
          _td colspan: 4
        end

        _tr do
          _td 'Net'
          _td.num -212
          _td.num -55
          _td.num.net! @budget.net.toLocaleString()
        end

        _tr do
          _td colspan: 4
        end

        _tr do
          _td 'Cash'
          _td.num 1_767.toLocaleString()
          _td.num 595
          _td.num.cash! @budget.cash.toLocaleString(),
            class: (@budget.cash < 0 ? 'danger' : 'success')
        end
      end
    end

    _p "Units are in thousands of dollars US."
  end

  # evaluate computed fields
  def recalc()
    @budget.income = @budget.donations + @budget.sponsorship + 28 + 4

    @budget.expense = @budget.infrastructure + 27 + @budget.publicity +
      @budget.brandManagement + @budget.conferences +
      @budget.travelAssistance + @budget.treasury + @budget.fundraising +
      @budget.generalAndAdministrative;

    @budget.net = @budget.income - @budget.expense

    @budget.cash = 1767 + # Virtual's projection for cash on hand at the end
                          # of FY18.

                   (2*-212) + (3*@budget.net) +
                          # linear projection for expenses from FY18 to FY23.
                          # Presuming:
                          #   FY19 = FY18 + 1 * (FY23-FY18)/5
                          #   FY20 = FY18 + 2 * (FY23-FY18)/5
                          #   FY21 = FY18 + 3 * (FY23-FY18)/5
                          #   FY22 = FY18 + 4 * (FY23-FY18)/5
                          #   FY23 = FY18 + 5 * (FY23-FY18)/5
                          # Total  = 5*Fy18 + 15*(FY23-FY18/5
                          #        = 5*Fy18 + 3*(FY23-FY18)
                          #        = 5*Fy18 + 3*FY23 - 3 * FY18
                          #        = 2*Fy18 + 3*FY23

                   2*100 +
                          # EA adjustment: instead of ramping down, the
                          # reduction in expense is immediate and constant.

                   600
                          # BTC adjustment: we expect to see a minimum of $600K
                          # from the recent PineApple Fund BTC donation.
  end

  # update budget item when an input field changes
  def change(event)
    console.log 'event.target.id'
    @budget[event.target.id] = parseInt(event.target.value.gsub(/\D/, '')) || 0
    event.target.value = @budget[event.target.id].toLocaleString()
    self.recalc()

    if User.role == :secretary and Minutes.started
      post 'budget', agenda: Agenda.file, budget: @budget do |budget|
        @budget = budget if budget
      end
    end

    Vue.forceUpdate()
  end

  # receive updated budget values
  def created()
    self.recalc();
    budget = Minutes.get('budget')

    if budget and budget != @budget and Minutes.started

      budget.each_pair do |item, date|
        element = document.getElementById(item)

        if element.tagName == 'INPUT'
          element.value = date.toLocaleString()
        else
          element.textContent = date.toLocaleString()
        end
      end

      @budget = budget
      @disabled = true unless User.role == :secretary
    end
  end
end
