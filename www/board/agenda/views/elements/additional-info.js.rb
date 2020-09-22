#
# Display information associated with an agenda item:
#   - special notes
#   - minutes
#   - posted reports
#   - action items
#   - posted comments
#   - pending comments
#   - historical comments
#
# Note: if AdditionalInfo is included multiple times in a page, set
#       prefix to true (or a string) to ensure rendered id attributes
#       are unique.
#

class AdditionalInfo < Vue
  def render
    # special notes
    if @@item.rejected
      _p.rejected 'Report was not accepted'
    end

    if @@item.notes
      _p @@item.notes,
        class: ('notes' unless @@item.notes =~ /^new, monthly through/)
    end

    # minutes
    minutes = Minutes.get(@@item.title)
    if minutes
      _h4 'Minutes', id: "#{@prefix}minutes"
      _pre.comment minutes
    end

    # posted reports
    if @@item.missing
      posted = Posted.get(@@item.title)
      unless posted.empty?
        _h4 'Posted reports', id: "#{@prefix}posted"
        _ul.posted_reports posted do |post|
          _li do
            _a post.subject, href: post.link
          end
        end
      end
    end

    # draft reports
    draft = Reporter.find(@@item)
    if draft and @prefix
      _span.hilite do
        _em 'Unposted draft being prepared at '
        _a 'reporter.apache.org',
          href: "https://reporter.apache.org/wizard?#{draft.project}"
      end
    end

    # action items
    if @@item.title != 'Action Items' and not @@item.actions.empty?
      _h4 id: "#{@prefix}actions" do
        _Link text: 'Action Items', href: 'Action-Items'
      end
      _ActionItems item: @@item, filter: {pmc: @@item.title}
    end

    unless @@item.special_orders.empty?
      _h4 'Special Orders', id: "#{@prefix}orders"
      _ul do
        @@item.special_orders.each do |resolution|
          _li do
            _Link text: resolution.title, href: resolution.href
          end
        end
      end
    end

    # posted comments
    history = HistoricalComments.find(@@item.title)
    if not @@item.comments.empty? or (history and not @prefix)
      _h4 'Comments', id: "#{@prefix}comments"
      @@item.comments.each do |comment|
        _pre.comment do
          _Text raw: comment, filters: [hotlink]
        end
      end

      # pending comments
      if @@item.pending
        _div.comment.commented.clickable onClick: -> {Main.navigate 'queue'} do
          _h5 'Pending Comment', id: "#{@prefix}pending"
          _pre.commented Flow.comment(@@item.pending, User.initials)
        end
      end

      # historical comments
      if history and not @prefix
        history.each_pair do |date, comments|
          next if Agenda.file == "board_agenda_#{date}.txt"

          _h5.history do
            _span "\u2022 "
            _a date.gsub('_', '-'),
              href: HistoricalComments.link(date, @@item.title)

            link = nil


            # link to mail archive for feedback thread
            if date > '2016_04' # when feedback emails were first started
              # compute date range: from date of that meeting to now
              dfr = date.gsub('_', '-')
              dto = Date.new(Date.now()).toISOString()[0...10]
              count = Responses.find(dfr, @@item.title)

              if count
                # when board was copied on the initial email
                count -= 1 if date < '2017_11'

                if count == 0
                  link = "(no responses)"
                elsif count == 1
                  link = '(1 response)'
                else
                  link = "(#{count} responses)"
                end

              elsif Responses.loading
                link = '(loading)'
              else
                link = '(no responses)'
              end
            end

            if link
              _span ': '

              _a link,
                href: 'https://lists.apache.org/list.html?board@apache.org&' +
                  "d=dfr=#{dfr}|dto=#{dto}&header_subject=" +
                  "'Board%20feedback%20on%20#{dfr}%20#{@@item.title}%20report'"
            end
          end

          splitComments(comments).each do |comment|
            _pre.comment do
              _Text raw: comment, filters: [hotlink]
            end
          end
        end
      end
    else
      # pending comments
      if @@item.pending
        _div.comment.commented.clickable onClick: -> {Main.navigate 'queue'} do
          _h5 'Pending Comment', id: "#{@prefix}pending"
          _pre.commented Flow.comment(@@item.pending, User.initials)
        end
      end
    end
  end

  # determine prefix (if any)
  def created()
    if @@prefix == true
      @prefix = @@item.title.downcase() + '-'
    elsif @@prefix
      @prefix = @@prefix
    else
      @prefix = ''
    end
  end
end
