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
      User.firstname and @@item.shepherd and
      User.firstname.start_with? @@item.shepherd.downcase()
    then
      return 'btn-primary'
    else
      return 'btn-link'
    end
  end

  # launch email client, pre-filling the destination, subject, and body
  def launch_email_client()
    mail_list = @@item.mail_list
    mail_list = "private@#{mail_list}.apache.org" unless mail_list.include? '@'

    to = @@item.chair_email
    cc = "#{mail_list},#{@@item.cc}"

    if @@item.missing
      subject = "Missing #{@@item.title} Board Report"
      body = %{
        Dear #{@@item.owner},

        The board report for #{@@item.title} has not yet been submitted for
        this month's board meeting. If you or another member of the PMC are
        unable to get it in by twenty-four hours before meeting time, please
        let the board know, and plan to report next month.

          https://www.apache.org/foundation/board/reporting#how

        Thanks,

        #{Server.username}

        (on behalf of the ASF Board)
      }

      # strip indentation; concatenate lines within a paragraph
      indent = body[/^\s*/]
      body = body.strip().gsub(/#{indent}/, "\n").gsub(/(\S)\n(\S)/, "$1 $2")
    else
      subject = "#{@@item.title} Board Report"
      body = @@item.comments.join("\n\n")

      if not body and @@item.text
        to = mail_list
        cc = @@item.cc
        body = @@item.text
      end
    end

    window.location = "mailto:#{to}?cc=#{cc}" +
      "&subject=#{encodeURIComponent(subject)}" +
      "&body=#{encodeURIComponent(body)}"
  end
end
