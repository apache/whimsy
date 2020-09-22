#
# Send email
#

class Email < Vue
  def initialize
    @email = {}
  end

  def render
    _button.btn 'send email', class: self.mailto_class(),
      onClick: self.launch_email_client

    _EmailForm email: @email, id: @@item.mail_list
  end

  # render 'send email' as a primary button if the viewer is the shepherd for
  # the report, otherwise render the text as a simple link.
  def mailto_class()
    if
      User.firstname and @@item.shepherd and
      User.firstname.start_with? @@item.shepherd.downcase()
    then
      if @@item.missing and not Posted.get(@@item.title).empty?
        return 'btn-link'
      else
        return 'btn-primary'
      end
    elsif
      @@item.owner == User.username and not @@item.missing and
        @@item.comments.empty?
    then
      return 'btn-primary'
    else
      return 'btn-link'
    end
  end

  # launch email client, pre-filling the destination, subject, and body
  def launch_email_client(event)
    mail_list = @@item.mail_list
    mail_list = "private@#{mail_list}.apache.org" unless mail_list.include? '@'

    to = @@item.chair_email
    cc = "#{mail_list},#{@@item.cc}"

    if @@item.missing
      subject = "Missing #{@@item.title} Board Report"
      if @@item.attach =~ /^\d/
        body = %{
          Dear #{@@item.owner},

          The board report for #{@@item.title} has not yet been submitted for
          this month's board meeting.  Please try to submit these reports by the
          Friday before the meeting.

          Thanks,

          #{User.username}
        }
      else
        body = %{
          Dear #{@@item.owner},

          The board report for #{@@item.title} has not yet been submitted for
          this month's board meeting. If you or another member of the PMC are
          unable to get it in by twenty-four hours before meeting time, please
          let the board know, and plan to report next month.

            https://www.apache.org/foundation/board/reporting#how

          Thanks,

          #{User.username}

          (on behalf of the ASF Board)
        }
      end

      # strip indentation; concatenate lines within a paragraph
      indent = body[/^\s*/]
      body = body.strip().gsub(/#{indent}/, "\n").gsub(/(\S)\n(\S)/, "$1 $2")
    else
      subject = "#{@@item.title} Board Report"
      body = @@item.comments.join("\n\n")

      if not body and @@item.text
        monthNames = %w(January February March April May June July August
          September October November December)
        year = Agenda.date.split('-')[0].to_i
        month = Agenda.date.split('-')[1].to_i

        subject = "[REPORT] #{@@item.title} - #{monthNames[month-1]} #{year}"
        to = @@item.cc
        cc = mail_list
        body = @@item.text
      end
    end

    if event.ctrlKey or event.shiftKey or event.metaKey
      @email = {
        to: to,
        cc: cc,
        subject: subject,
        body: body
      }

      jQuery('#email-' + @@item.mail_list).modal(:show)
    else
      window.location = "mailto:#{to}?cc=#{cc}" +
        "&subject=#{encodeURIComponent(subject)}" +
        "&body=#{encodeURIComponent(body)}"
    end
  end
end

class EmailForm < Vue
  def render
    _ModalDialog color: 'commented', id: 'email-' + @@id do
      _h4 "Send email - #{@@email.subject}"

      # input field: to
      _div.form_group.row do
        _label.col_sm_2 'To', for: 'email-to'
        _input.col_sm_10.email_to! placeholder: "destination email address",
          disabled: @disabled, value: @@email.to
      end

      # input field: cc
      _div.form_group.row do
        _label.col_sm_2 'CC', for: 'email-cc'
        _input.col_sm_10.email_cc! placeholder: "cc list", disabled: @disabled,
          value: @@email.cc
      end

      # input field: subject
      _div.form_group.row do
        _label.col_sm_2 'Subject', for: 'email-subject'
        _input.col_sm_10.email_subject! placeholder: "email subject",
        disabled: @disabled, value: @@email.subject
      end

      # input field: body
      _textarea.email_body! label: 'Body', placeholder: "email text",
        disabled: @disabled, value: @@email.body, rows: 10

      _button.btn_default 'Cancel', type: 'button', data_dismiss: 'modal'
      _button.btn_primary 'Send', type: 'button', onClick: self.send,
        disabled: @disabled
    end
  end

  def send(event)
    @disabled = true
    post 'email', @@email do |response|
      console.log response
      @disabled = false
      jQuery('#email-' + @@id).modal(:hide)
      document.body.classList.remove('modal-open')
    end
  end
end
