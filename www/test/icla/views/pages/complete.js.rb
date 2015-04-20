class Complete < React
  def render
    _p %{
      At this point, the demo is complete.  If this were a real application:
    }

    _ul do
      _li 'An file would have been committed to SVN.'
      _li 'An email would have been sent to the PMC.'

      if FormData.apacheid
        _li 'An new account request would have been submitted.'
      end
    end
  end
end
