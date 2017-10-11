#
# Send email
#

class Email < Vue
  def render
    _button.btn 'send email', class: self.mailto_class(),
      onClick: self.launch_email_client
  end

  # render 'send email' as a primary button if the viewer is the shepherd for
  # the report, otherwise render the text as a simple link.
  def mailto_class()
    if 
      Server.firstname and @@item.shepherd and
      Server.firstname.start_with? @@item.shepherd.downcase()
    then
      return 'btn-primary'
    else
      return 'btn-link'
    end
  end

  # launch email client, pre-filling the destination, subject, and body
  def launch_email_client()
    destination = "mailto:#{@@item.chair_email}" +
      "?cc=private@#{@@item.mail_list}.apache.org,board@apache.org"

    if @@item.missing
      subject = "Missing #{@@item.title} Board Report"
      body = "Dear #{@@item.owner},\n\nThe board report for " +
        "#{@@item.title} has not yet been submitted for this " +
        "month's board meeting. If you or another member of the PMC are unable to get "+
        "it in by twenty-four hours before meeting time, " +
        "please let the board know, and plan to report next month.\n\n" + 
        '  https://www.apache.org/foundation/board/reporting#how' +
        "\n\nThanks,\n\n " +
        "#{Server.username}\n\n" +
        "(on behalf of the ASF Board)"
    else
      subject = "#{@@item.title} Board Report"
      body = @@item.comments
    end

    window.location = destination +
      "&subject=#{encodeURIComponent(subject)}" +
      "&body=#{encodeURIComponent(body)}"
  end
end
