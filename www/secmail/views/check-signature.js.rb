class CheckSignature < React
  def initialize
    @signature = nil
    @checked = nil
  end

  def render
    if @signature
      _div.alert @alert, class: @flag
    end
  end

  def componentDidMount()
    self.componentWillReceiveProps()
  end

  def componentWillReceiveProps()
    @signature = @@attachments.find {|attachment|
      attachment == @@selected + '.asc' or attachment == @@selected + '.sig'
    }

    if @signature and @signature != @checked
      @flag = 'alert-info'
      @alert = 'checking signature'

      data = {
        message: window.parent.location.pathname,
        attachment: @@selected,
        signature: @signature
      }

      HTTP.post('../../actions/check-signature', data).then {|response|
        output = response.output + response.error

        if output.include? 'Good signature'
          @flag = 'alert-success'
        else
          @flag = 'alert-danger'
        end

        @alert = output
        @checked = @signature
      }.catch {|error|
        @alert = error
        @flag = 'alert-warning'
      }
    end
  end
end
