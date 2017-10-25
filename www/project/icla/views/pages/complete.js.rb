class Complete < Vue
  def render
    _p %{
      At this point, the demo is complete.  If this were a real application:
    }

    _ul do
      _li {_p 'An file would have been committed to SVN.'}

      _li do
        _p 'Commit message would include the following IP address information:'
        _pre FormData.ipaddr
      end

      _li {_p 'An email would have been sent to the PMC.'}

      if FormData.apacheid
        _li {_p 'An new account request would have been submitted.'}
      end
    end
  end
end
