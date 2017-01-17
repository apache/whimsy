#
# Show a PPMC
#

class PPMC < React
  def render
    auth = @@auth and (@@auth.secretary or @@auth.root)

    # header
    _h1 do
      _a @@ppmc.display_name, 
        href: "https://incubator.apache.org/projects/#{@@ppmc.id}.html"
      _small " established #{@ppmc.established}" if @ppmc.established
    end

    _p @ppmc.description

    # usage information for authenticated users (PMC chair, etc.)
    if auth
      _div.alert.alert_success do
        _span 'Double click on a row to show actions.'
        unless @ppmc.roster.keys().empty?
          _span "  Click on \u2795 to add."
        end
      end
    end

    # main content
    _PPMCMembers auth: auth, ppmc: @ppmc

    # mailing lists
    _h2.mail! 'Mail lists'
    _ul do
      for mail_name in @ppmc.mail
        parsed = mail_name.match(/^(.*?)-(.*)/)
        _li do
          _a mail_name, href: 'https://lists.apache.org/list.html?' +
            "#{parsed[2]}@#{parsed[1]}.apache.org"
        end
      end
    end

    # reporting schedule
    _h2.reporting! 'Reporting Schedule'
    _ul do
      _li @ppmc.schedule.join(', ')

      _li do
        _a 'Prior reports', href: 'https://whimsy.apache.org/board/minutes/' +
          @ppmc.display_name.gsub(/\s+/, '_')
      end
    end

    # hidden form
    _PPMCConfirm pmc: @ppmc.id, update: self.update if auth
  end

  # capture ppmc on initial load
  def componentWillMount()
    self.update(@@ppmc)
  end

  # capture ppmc on subsequent loads
  def componentWillReceiveProps()
    self.update(@@ppmc)
  end

  # update ppmc from conformation form
  def update(ppmc)
    @ppmc = ppmc
  end
end
