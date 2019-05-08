class InsiderSecrets < Vue
  def render
    _p %q(
      Following are some of the less frequently used features that aren't
      prominently highlighted by the UI, but you might find useful.
    )

    _ul do
      _li { _p %q(
        Want to reflow only part of a report so as to not mess with the
        formatting of a table or other pre-formatted text?  Select the
        lines you want to adjust using your mouse before pressing the
        reflow button.
      ) }

      _li { _p %q(
        Want to not use your email client for whatever reason?  Press
        shift before you click a 'send email' button and a form will
        drop down that you can use instead.
      ) }

      _li { _p %q(
        Action items have both a status (which is either shown with a red
        background if no update has been made or a white background if
        a status has been provided), and a PMC name.  The background of the
        later is either grey if this PMC is not reporting this month, or
        a link to the report itself, and the color of the link is the color
        associated with the report (green if preapproved, red if flagged,
        etc.).  So generally if you see an action item to "pursue a report
        for..." and the link is green, you can confidently mark that action as
        complete.
      ) }
    end
  end

  _Link text: 'Back to the agenda', href: '.'
end
