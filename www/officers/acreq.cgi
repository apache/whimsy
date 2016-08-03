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

require 'wunderbar/jquery'
require 'whimsy/asf'
require 'mail'
require 'date'
require 'open3'
require 'pathname'
require 'rexml/document'
require 'net/http'


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

SVN = "/usr/bin/svn"
ACREQ = ASF::SVN['infra/infrastructure/trunk/acreq']
OFFICERS = ASF::SVN['private/foundation/officers']
APMAIL_BIN = ASF::SVN['infra/infrastructure/apmail/trunk/bin']

# get up to date...
`#{SVN} cleanup #{ACREQ} #{OFFICERS} #{APMAIL_BIN}`
`#{SVN} revert -R #{ACREQ}` if ENV[' REQUEST_METHOD'] == 'POST'
unless `#{SVN} status -q #{ACREQ}`.empty?
  raise "acreq/ working copy is dirty"
end
`#{SVN} update --ignore-externals #{ACREQ}`

REQUESTS = "#{ACREQ}/new-account-reqs.txt"

# grab the current list of PMCs from ldap
pmcs = ASF::Committee.list.map(&:name).sort - NON_PMC_UNIX_GROUPS

# grab the list of podling mailing lists from apmail
podlings = ASF::Podling.list.map(&:name).sort

# grab the list of iclas that have no ids assigned
query_string = CGI::parse ENV['QUERY_STRING']
if query_string.has_key? 'fulllist'
  iclas = Hash[*File.read("#{OFFICERS}/iclas.txt").
    scan(/^notinavail:.*?:(.*?):(.*?):Signed CLA/).flatten.reverse]
else
  oldrev = \
    `#{SVN} log --incremental -q -r HEAD:0 -l300 -- #{OFFICERS}/iclas.txt`.
    split("\n")[-1].split()[0][1..-1].to_i
  iclas = Hash[*`#{SVN} diff -r #{oldrev}:HEAD -- #{OFFICERS}/iclas.txt`.
    scan(/^[+]notinavail:.*?:(.*?):(.*?):Signed CLA/).flatten.reverse]
end

# grab the list of userids that have been assigned (for validation purposes)
taken = File.read("#{OFFICERS}/iclas.txt").scan(/^(\w+?):/).flatten.sort.uniq

# add the list of userids that are pending
taken += File.read(REQUESTS).scan(/^(\w.*?);/).flatten

# add member ids that do not have ICLAs
taken += %w(andi andrei arved dgaudet pcs rasmus ssb zeev)  

# add list of ids that match ones with embedded hyphens, e.g. an-selm (INFRA-7390)
taken += %w(an james jean rgb soc swaroop)  

# add list of tokens that could be mistaken for names
taken += %w(r rw)  

# get a list of pending new account requests (by email)
pending = File.read(REQUESTS).scan(/^\w.*?;.*?;(.*?);/).flatten

# remove pending email addresses from the selection list
pending.each {|email| iclas.delete email}

# HTML output
_html do
  _head do
    _title 'Submit ASF Account Request'

    _style! <<-'EOF'
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
    EOF

    ENV['SCRIPT_FILENAME'] =~ /(.*)/
    sf = $1
    sf.untaint
    
    ENV['DOCUMENT_ROOT'] =~ /(.*)/
    dr = $1
    dr.untaint
    
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

        _input type: "submit", value: "Submit"
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

        # capture submitter information
        ENV['REMOTE_USER'] =~ /(\w+)/
        submitter_id = $1
        submitter_id.untaint
        
        submitter_name = 
          File.read("#{OFFICERS}/iclas.txt")[/^#{submitter_id}:.*?:(.*?):/,1]
        submitter_name.untaint
        
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
          if submitter_name
            from  "#{submitter_name} <#{submitter_id}@apache.org>"
          else
            from  "#{submitter_id}@apache.org"
          end
          return_path "root@apache.org"
          to      "root@apache.org"
          cc      cc_list
          subject "[FORM] Account Request - #{requestor}: #{@name}"

          ENV['REMOTE_ADDR'] =~ /(\w[\w.-]+)/
          ra = $1
          ra.untaint

          body <<-EOF.gsub(/^ {12}/, '').gsub(/(Vote reference:)?\n\s+\n/, "\n\n")
            Prospective userid: #{@user}
            Full name: #{@name}
            Forwarding email address: #{@email}

            Vote reference:
              #{@votelink.gsub('mail-search.apache.org/pmc/', 'mail-search.apache.org/members/')}

            #{@comments}

            -- 
            Submitted by https://#{ENV['HTTP_HOST']}#{ENV['REQUEST_URI'].split('?').first}
            From #{`/usr/bin/host #{ra}`.chomp}
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
          requests = File.read(REQUESTS)
          File.open(REQUESTS, 'w') do |file|
            file.write("#{requests}#{line}\n")
          end

          # and commit the change ...
          command = "#{SVN} commit #{ACREQ}/new-account-reqs.txt -m " + 
            "#{requestor} account request by #{submitter_id}".inspect
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
        if @fulllist
          _span 'This page shows all ICLAs ever received.  Click here to'
          _a 'show only ICLAs received recently', href: '?'
          _span '.'
        else
          _span 'This page shows only ICLAs received recently.  Click here to'
          _a 'choose from the full list of ICLA submitters', href: '?fulllist=1'
          _span '.'
        end
      end
    end
  end
end
