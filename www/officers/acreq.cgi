#!/usr/bin/ruby
#
#   Build a properly formatted and validated new-account-reqs.txt entry based
#   on web input.  Does both full client validation and Server-side
#   validation.
#
#   Should validation succeed, the entry will be appended to the
#   new-account-reqs.txt and committed.  An email will be sent to root
#   (copying the relevant pmc private list) of the request.
#
#   The response contains
#   the messages produced by the commit (if any) in the response, and
#   a copy of the email that was sent.
#

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))

require 'wunderbar/jquery'
require 'whimsy/asf/rack'
require 'mail'
require 'date'
require 'open3'

user = ASF::Auth.decode(env = {})
unless user.asf_member? or ASF.pmc_chairs.include? user
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

# List of unix groups that do NOT correspond to PMCs
NON_PMC_UNIX_GROUPS = %w(
  apsite
  audit
  board
  committers
  concom
  db-site
  incubator-site
  member
)

ACREQ = 'https://svn.apache.org/repos/infra/infrastructure/trunk/acreq'
OFFICERS = 'https://svn.apache.org/repos/private/foundation/officers'
APMAIL_BIN = ASF::SVN['infra/infrastructure/apmail/trunk/bin']

# get up to date data...
SVN = "/usr/bin/svn --username #{env.user} --password #{env.password}"
requests = `#{SVN} cat #{ACREQ}/new-account-reqs.txt`
iclas_txt = `#{SVN} cat #{OFFICERS}/iclas.txt`

# grab the current list of PMCs from ldap
pmcs = ASF::Committee.list.map(&:name).sort - NON_PMC_UNIX_GROUPS

# grab the list of active podlings
podlings = ASF::Podling.list.select {|podling| podling.status == 'current'}.
  map(&:name).sort

# grab the list of iclas that have no ids assigned
query = CGI::parse ENV['QUERY_STRING']
iclas = Array(query['iclas']).last
email = Array(query['email']).last
if iclas == 'all'
  iclas = Hash[*iclas_txt.scan(/^notinavail:.*?:(.*?):(.*?):Signed CLA/).
    flatten.reverse]
elsif iclas == '1' and email and iclas_txt =~ /^notinavail:.*?:(.*?):#{email}:/
  iclas = {email => $1}
else
  count = iclas ? iclas.to_i : 300 rescue 300
  oldrev = \
    `#{SVN} log --incremental -q -r HEAD:0 -l#{count} -- #{OFFICERS}/iclas.txt`.
    split("\n")[-1].split()[0][1..-1].to_i
  iclas = Hash[*`#{SVN} diff -r #{oldrev}:HEAD -- #{OFFICERS}/iclas.txt`.
    scan(/^[+]notinavail:.*?:(.*?):(.*?):Signed CLA/).flatten.reverse]
end

# grab the list of userids that have been assigned (for validation purposes)
taken = iclas_txt.scan(/^(\w+?):/).flatten.sort.uniq

# add the list of userids that are pending
taken += requests.scan(/^(\w.*?);/).flatten

# add member ids that do not have ICLAs
taken += %w(andi andrei arved dgaudet pcs rasmus ssb zeev)  

# add list of ids that match ones with embedded hyphens, e.g. an-selm (INFRA-7390)
taken += %w(an james jean rgb soc swaroop)  

# add list of tokens that could be mistaken for names
taken += %w(r rw)  

# get a list of pending new account requests (by email)
pending = requests.scan(/^\w.*?;.*?;(.*?);/).flatten

# remove pending email addresses from the selection list
pending.each {|email| iclas.delete email}

# HTML output
_html do
  _head do
    _title 'Submit ASF Account Request'

    _style %{
      label {width: 6em; float: left}
      legend {background: #141; color: #DFD; padding: 0.4em}
      fieldset {background: #EFE; width: 28em}
      fieldset div {clear: both; padding: 0.4em 0 0 1.5em}
      input,textarea {width: 3in}
      select {width: 3.06in}
      input[type=checkbox] {margin-left: 6em; width: 1em}
      input[type=submit] {margin-top: 0.5em; margin-left: 3em; width: 8em}
      .error {margin: 1em; padding: 1em; background: red; color: white}
      .stdout {background-color: yellow; margin: 0}
      .stderr {background-color: red; color: white; margin: 0}
      pre.email {background-color: #BDF; padding: 1em 3em; border-radius: 1em}
    }

    _script %{
      $(function() {

        // if name changes, change email to match
        $('#name').change(function() {
          $("option:selected").each(function() {
            var email = $(this).attr('data-email');
            if (email) $('#email').val(email);
          });
        });

        // if email changes, change name to match
        $('#email').change(function() {
          $("option:selected").each(function() {
            var name = $(this).attr('data-name');
            if (name) $('#name').val(name);
          });
        });

        // if user changes, validate that the id is available
        $('#user').focus().blur(function() {
          if ($.inArray($(this).val(),#{taken.to_json}) != -1) {
            this.setCustomValidity('userid is not available');
          } else {
            this.setCustomValidity('');
          }
        });

        // if pmc is incubator, enable podling, else disable and clear podling
        $('#pmc').change(function() {
          if ($(this).val() == 'incubator') {
            $('#podling').removeAttr('disabled', 'disabled');
          } else {
            $('#podling').attr('disabled', 'disabled')[0].
              selectedIndex = -1;
          }
        });

        // allow selected fields to be set based on parameters passed
        if (#{@user.to_s.inspect} != '')
          $('#user').val(#{@user.to_s.inspect});
        $('#email').val(#{@email.to_s.inspect}).trigger('change');
        $('#pmc').val(#{@pmc.to_s.inspect}).trigger('change').
          attr('required', 'required');
        $('#podling').val(#{@podling.to_s.inspect});
        if (#{@votelink.to_s.inspect} != '')
          $('#votelink').val(#{@votelink.to_s.inspect});
      });
    }
  end

  _body do
    _form method: 'post' do
      _fieldset do
        _legend 'ASF New Account Request'

        _div do
          _label 'User ID', for: "user"
          _input name: "user", id: "user", autofocus: true,
            type: "text", required: true,
            pattern: '^[a-z][-a-z0-9_]+$' # useridvalidationpattern dup
        end

        _div do
          _label 'Name', for: "name"
          _select name: "name", id: "name", required: true do
            _option value: ''
            iclas.invert.to_a.sort.each do |name, email|
              _option name, value: name, data_email: email
            end
          end
        end

        _div do
          _label 'Email', for: "email"
          _select name: "email", id: "email", required: true do
            _option value: ''
            iclas.to_a.sort_by {|email, name| email.downcase}.
              each do |email, name|
              _option email.downcase, value: email, data_name:name
            end
          end
        end

        _div do
          _label 'PMC', for: "pmc"
          _select name: "pmc", id: "pmc" do
            _option value: ''
            pmcs.each do |pmc| 
              _option pmc, value: pmc
            end
          end
        end

        _div do
          _label 'Podling', for: "podling"
          _select name: "podling", id: "podling" do
            _option value: ''
            podlings.each do |podling| 
              _option podling, value: podling
            end
          end
        end

        _div do
          _label 'Vote Link', for: "votelink"
          _input name: "votelink", id: "votelink", type: "text",
            pattern: '.*://.*|.*@.*'
        end

        _div do
          _label 'Comments', for: "comments"
          _textarea name: "comments", id: "comments" 
        end

        _input type: "submit", value: "Submit", disabled: true
      end
    end

    if _.post?
      # server side validation
      if pending.include? @email
        _div.error "Account request already pending for #{@email}"
      elsif taken.include? @user
        _div.error "UserID #{@user} is not available"
      elsif @user !~ /^[a-z][a-z0-9_]+$/ # useridvalidationpattern dup (disallow '-' in names because of INFRA-7390)
        _div.error "Invalid userID #{@user}"
      elsif @user.length > 16
        # http://forums.freebsd.org/showthread.php?t=14636
        _div.error "UserID #{@user} is too long (max 16)"
      elsif @pmc !~ /^[0-9a-z-]+$/
        _div.error "Unsafe PMC #{@pmc}"
      elsif @podling and @podling !~ /^[0-9a-z-]*$/
        _div.error "Unsafe podling name #{@podling}"
      elsif not iclas.include? @email
        _div.error "No ICLA on record for #{@email}"
      elsif not iclas[@email] == @name
        _div.error "Name #{@name} does not match name on ICLA"
      elsif not pmcs.include? @pmc
        _div.error "Unrecognized PMC name #{@pmc}"
      else

        # verb tense to be used in messages
        tobe = 'to be ' if DEMO_MODE

        # build the line to be added
        line = "#{@user};#{@name};#{@email};#{@pmc};" +
          "#{@pmc};#{Date.today.strftime('%m-%d-%Y')};yes;yes;no;"

        # determine the requesting party and cc_list
        @pmc =~ /([\w.-]+)/
        requestor = $1
        requestor.untaint
        cc_list = ["private@#{@pmc}.apache.org".untaint]
        if requestor == 'incubator' and not @podling.empty?
          if File.read("#{APMAIL_BIN}/.archives").include? "incubator-#{@podling}-private"
            cc_list << "#{@podling}-private@#{@pmc}.apache.org".untaint
          else
            cc_list << "private@#{@podling}.#{@pmc}.apache.org".untaint
          end
          requestor = "#{@podling}@incubator".untaint
        end
        cc_list << "<#{@email}>".untaint # TODO: add @name RFC822-escaped

        # build the mail to be sent
        mail = Mail.new do
          from  "#{user.public_name} <#{user.id}@apache.org>"
          return_path "root@apache.org"
          to      "root@apache.org"
          cc      cc_list
          subject "[FORM] Account Request - #{requestor}: #{@name}"

          body <<-EOF.gsub(/^ {12}/, '').gsub(/(Vote reference:)?\n\s+\n/, "\n\n")
            Prospective userid: #{@user}
            Full name: #{@name}
            Forwarding email address: #{@email}

            Vote reference:
              #{@votelink.gsub('mail-search.apache.org/pmc/', 'mail-search.apache.org/members/')}

            #{@comments}

            -- 
            Submitted by https://#{ENV['HTTP_HOST']}#{ENV['REQUEST_URI'].split('?').first}
            From #{`/usr/bin/host #{ENV['REMOTE_ADDR'].dup.untaint}`.chomp}
            Using #{ENV['HTTP_USER_AGENT']}
          EOF
        end

        unless DEMO_MODE
          # deliver the email.  Done first as undeliverable mail stops
          # the process
          begin
            mail.deliver!
          rescue Exception => exception
            _pre.error exception.inspect
            tobe = 'would have been '
          end
        end

        unless tobe
          # Update the new-account-reqs file...
          File.open(REQUESTS, 'w') do |file|
            file.write("#{requests}#{line}\n")
          end

          # and commit the change ...
          command = "#{SVN} commit #{ACREQ}/new-account-reqs.txt -m " + 
            "#{requestor} account request by #{user.id}".inspect
          _h2 'Commit messages'
          Open3.popen3(command) do |pin, pout, perr|
            [
              Thread.new do
                _p.stdout pout.readline.chomp until pout.eof?
              end,
              Thread.new do
                _p.stderr perr.readline.chomp until perr.eof?
              end,
              Thread.new do
                pin.close
              end
            ].each {|thread| thread.join}
          end
        end

        # report on status
        _h2 "New entry #{tobe}added:"
        _pre line
        _h2 "Mail #{tobe}sent:"
        _pre.email mail.to_s
      end
    end

    unless _.post?
      _p do
        if @iclas == 'all'
          _span 'This page shows all ICLAs ever received.  Click here to'
          _a 'show only ICLAs received recently', href: '?'
          _span '.'
        else
          _span 'This page shows only ICLAs received recently.  Click here to'
          _a 'choose from the full list of ICLA submitters', href: '?iclas=all'
          _span '.'
        end
      end
    end
  end
end
