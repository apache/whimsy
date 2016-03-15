class Info < React
  def render
    _dl.dl_horizontal class: @@position do
      _dt 'Attach'
      _dd @@item.attach

      if @@item.owner
        _dt 'Author'
        _dd @@item.owner
      end

      if @@item.shepherd
        _dt 'Shepherd'
        _dd @@item.shepherd
      end

      if @@item.flagged_by and not @@item.flagged_by.empty?
        _dt 'Flagged By'
        _dd @@item.flagged_by.join(', ')
      end

      if @@item.approved and not @@item.approved.empty?
        _dt 'Approved By'
        _dd @@item.approved.join(', ')
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
