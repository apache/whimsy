#
# Check signatures for validity using gpg on the server
#

class CheckSignature < React
  def initialize
    @signature = nil
    @checked = nil
  end

  def render
    if @signature
      _div.alert @alert, class: @flag

      if @alert.include? 'public key not found'
        _div.buttons do
          _button.btn.btn_primary 'email user requesting upload',
            onClick: self.request_upload
        end
      end
    end
  end

  def componentDidMount()
    self.componentWillReceiveProps()
  end

  def componentWillReceiveProps()
    @signature = CheckSignature.find(@@selected, @@attachments)

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

  # find signature file that matches the selected attachment from the list
  # of attachments
  def self.find(selected, attachments)
    return unless selected

    # first look for a signature that matches this selected file
    signature = attachments.find {|attachment|
      attachment == selected + '.asc' or attachment == selected + '.sig'
    }

    # if no exact match, look closer at the other attachment if there
    # are exactly two attachments
    if not signature and attachments.length == 2
      signature = attachments.find {|attachment| attachment != selected}

      unless signature.end_with? '.asc' or signature.end_with? '.sig'
        signature = nil
      end
    end

    return signature
  end

  # send an email requesting that the user upload their signature
  def request_upload()
    destination = @@headers.From
    subject = "Re: #{@@headers.Subject}"
    body = "Please upload your public key.\n\nhttps://pgp.mit.edu/"

    window.location = "mailto:#{encodeURIComponent(destination)}" +
      "?subject=#{encodeURIComponent(subject)}" +
      "&body=#{encodeURIComponent(body)}"
  end
end
