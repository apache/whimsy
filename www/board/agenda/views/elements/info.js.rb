class Info < Vue
  def render
    _dl.dl_horizontal class: @@position do
      _dt 'Attach'
      _dd @@item.attach

      if @@item.owner
        _dt 'Author'
        if (@@item.chair_email || '') .split('@')[1] == 'apache.org'
          chair = @@item.chair_email .split('@')[0]
          _dd do
            _a @@item.owner,
              href: "https://whimsy.apache.org/roster/committer/#{chair}"
          end
        else
          _dd @@item.owner
        end
      end

      if @@item.shepherd
        _dt 'Shepherd'
        _dd do
          if @@item.shepherd
            _Link text: @@item.shepherd,
              href: "shepherd/#{@@item.shepherd.split(' ').first}"
          end
        end
      end

      if @@item.flagged_by and not @@item.flagged_by.empty?
        _dt 'Flagged By'
        _dd do
          @@item.flagged_by.each_with_index do |initials, index|
            _ ', ' unless index == 0
            _ Server.directors[initials] || initials
          end
        end
      end

      if @@item.approved and not @@item.approved.empty?
        _dt 'Approved By'
        _dd do
          @@item.approved.each_with_index do |initials, index|
            _ ', ' unless index == 0
            _span initials, title: Server.directors[initials]
          end
        end
      end

      if @@item.roster or @@item.prior_reports or @@item.stats
        _dt 'Links'

        if @@item.roster
          _dd { _a 'Roster', href: @@item.roster }
        end

        if @@item.prior_reports
          _dd { _a 'Prior Reports', href: @@item.prior_reports }
        end

        if @@item.stats
          _dd { _a 'Statistics', href: @@item.stats }
        end
      end
    end
  end
end
