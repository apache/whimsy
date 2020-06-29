#
# Post a new agenda
#

_html do
  _base href: @base
  _title 'ASF Board Agenda'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{@cssmtime}"
  _meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'

  _div.container.new_agenda! do
    if @next_month and not @next_month.empty?
      if ASF::Board.calendar.max < Time.now.utc
        _div.error do
          _h4 'No next meeting date set'
          _a 'committers/board/calendar.txt',
             href: ASF::SVN.svnpath!('board', 'calendar.txt')
          _span ' needs to be updated in svn with a list of future meeting dates.'
          _span ' Assuming third Wednesday of the month for the next meeting.'
        end
      end

      _div.commented do
        _h4 'Committees expected to report next month, and why:'
        _pre.commented @next_month.gsub(@next_month.scan(/\s+#/).max.to_s, " -")
      end

      if @next_month.include? "through #@prev_month"
        _h3.missing do
          _ "List still shows a committee as reporting through #@prev_month."
          _ "Perhaps committee-info.txt was not updated?"
        end
      elsif not @next_month.include? @prev_month
        _h3.missing do
          _ "No reports were marked missing or rejected in #@prev_month."
          _ "Perhaps committee-info.txt was not updated?"
        end
      end
    end

    _form method: 'post',  action: @meeting.strftime("%Y-%m-%d/") do

      _div.text_center do
        _button.btn.btn_primary 'Post', disabled: @disabled
      end

      _textarea.form_control @agenda, name: 'agenda',
        rows: [@agenda.split("\n").length, 20].max
    end

    _h3 'Sources'

    _ul do
      _li do
        _ 'Agenda was generated from '
        _a 'board_agenda.erb', href: ASF::SVN.svnpath!('foundation_board', '/templates/board_agenda.erb')
      end

      _li do
        _ 'Date and time of meeting was extracted from '
        _a 'calendar.txt', href: ASF::SVN.svnpath!('board', 'calendar.txt')
      end

      _li do
        _ 'Directors extracted from '
        _a 'LDAP', href: 'https://whimsy.apache.org/roster/group/board'
      end

      _li do
        _ 'Officers extracted from '
        _a 'committee-info.txt', href: ASF::SVN.svnpath!('board', 'committee-info.txt')
      end
    end
  end
end
