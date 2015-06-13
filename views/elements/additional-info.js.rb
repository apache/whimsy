#
# Display information associated with an an agenda item:
#   - posted reports
#   - posted comments
#   - pending comments
#   - action items
#   - minutes
#

class AdditionalInfo < React
  def render
    # posted reports
    if @@item.missing
      posted = Posted.get(@@item.title)
      unless posted.empty?
        _h4.comments! 'Posted reports'
        _ul posted do |post|
          _li do
            _a post.subject, href: post.link
          end
        end
      end
    end

    # posted comments
    unless @@item.comments.empty?
      _h4.comments! 'Comments'
      @@item.comments.each do |comment|
        _pre.comment do
          _Text raw: comment, filters: [hotlink]
        end
      end
    end

    # pending comments
    if @@item.pending
      _h4.comments! 'Pending Comment'
      _pre.comment Flow.comment(@@item.pending, Pending.initials)
    end

    # action items
    if @@item.title != 'Action Items' and not @@item.actions.empty?
      _h4 { _Link text: 'Action Items', href: 'Action-Items' }
      _ActionItems item: @@item, filter: {pmc: @@item.title}
    end

    # minutes
    minutes = Minutes.get(@@item.title)
    if minutes
      _h4 'Minutes'
      _pre.comment minutes
    end
  end
end
