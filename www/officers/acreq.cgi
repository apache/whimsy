#!/usr/bin/env ruby
PAGETITLE = "Apache Account Submission Helper Form" # Wvisible:infra accounts
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'whimsy/asf/rack'
require 'whimsy/asf'
require 'mail'
require 'date'
require 'open3'
require 'tmpdir'
require 'shellwords'

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
# TODO replace with library method see WHIMSY-103
SVN = ("svn --username #{Shellwords.escape env.user} " +
  "--password #{Shellwords.escape env.password}").untaint
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
taken = ASF::ICLA.availids_taken() # these are in use or reserved

# add the list of userids that are pending
taken += requests.scan(/^(\w.*?);/).flatten

# get a list of pending new account requests (by email)
pending = requests.scan(/^\w.*?;.*?;(.*?);/).flatten

# remove pending email addresses from the selection list
pending.each {|email| iclas.delete email}

# HTML output
_html do
  _head do
    _title PAGETITLE

    _style :system
    _style %{
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

  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'How To Make Account Requests',
      related: {
        'https://whimsy.apache.org/roster' => 'Whimsy Roster Tool',
        'https://reference.apache.org/infra' => 'Infra Reference Documentation',
        'https://reference.apache.org/pmc/acreq' => 'Infra How To Create New Account Docs'
      },
      helpblock: -> {
        _p %{
          This page builds a properly formatted and validated new-account-reqs.txt entry based
          on your input below.  Does both full client validation and Server-sidevalidation.
        }
        _p %{
          Should validation succeed, the entry will be appended to the
          new-account-reqs.txt and committed.  An email will be sent to root
          (copying the relevant pmc private list) of the request.
        }
        _p %{
          The response contains
          the messages produced by the commit (if any) in the response, and
          a copy of the email that was sent.
        }
      }
    ) do
      
      _div.row do
        _div.col_md_8 do
          # Display the data input form for an account request
          _whimsy_panel('Request A New Apache Account', style: 'panel-success') do
            _form.form_horizontal method: 'post' do
              _div.form_group do
                _label.control_label.col_sm_2 'User ID', for: "user"
                _div.col_sm_10 do
                  _input.form_control name: "user", id: "user", autofocus: true,
                    type: "text", required: true,
                    pattern: '^[a-z][-a-z0-9_]+$' # useridvalidationpattern dup
                end
              end

              _div.form_group do
                _label.control_label.col_sm_2 'Name', for: "name"
                _div.col_sm_10 do
                  _select.form_control name: "name", id: "name", required: true do
                    _option value: ''
                    iclas.invert.to_a.sort.each do |name, email|
                      _option name, value: name, data_email: email
                    end
                  end
                end
              end

              _div.form_group do
                _label.control_label.col_sm_2 'Email', for: "email"
                _div.col_sm_10 do
                  _select.form_control name: "email", id: "email", required: true do
                    _option value: ''
                    iclas.to_a.sort_by {|email, name| email.downcase}.
                      each do |email, name|
                      _option email.downcase, value: email, data_name:name
                    end
                  end
                end
              end

              _div.form_group do
                _label.control_label.col_sm_2 'PMC', for: "pmc"
                _div.col_sm_10 do
                  _select.form_control name: "pmc", id: "pmc" do
                    _option value: ''
                    pmcs.each do |pmc| 
                      _option pmc, value: pmc
                    end
                  end
                end
              end

              _div.form_group do
                _label.control_label.col_sm_2 'Podling', for: "podling"
                _div.col_sm_10 do
                  _select.form_control name: "podling", id: "podling" do
                    _option value: ''
                    podlings.each do |podling| 
                      _option podling, value: podling
                    end
                  end
                end
              end

              _div.form_group do
                _label.control_label.col_sm_2 'Vote Link', for: "votelink"
                _div.col_sm_10 do
                  _input.form_control name: "votelink", id: "votelink", type: "text",
                    pattern: '.*://.*|.*@.*', placeholder: 'https://lists.apache.org/list.html?dev@project.apache.org'
                end
              end

              _div.form_group do
                _label.control_label.col_sm_2 'Comments', for: "comments"
                _div.col_sm_10 do
                  _textarea.form_control name: "comments", id: "comments" 
                end
              end
              
              _div.form_group do
                _div.col_sm_offset_2.col_sm_10 do
                  _input.btn.btn_default type: "submit", value: "Submit"
                end
              end
            end

            # If making a request, validate, checkin, and display results
            if _.post?
              _div.well.well_lg do
                # server side validation
                if pending.include? @email
                  _div.bg_danger "Account request already pending for #{@email}"
                elsif taken.include? @user
                  _div.bg_danger "UserID #{@user} is not available"
                elsif @user !~ /^[a-z][a-z0-9_]+$/ # useridvalidationpattern dup (disallow '-' in names because of INFRA-7390)
                  _div.bg_danger "Invalid userID #{@user}"
                elsif @user.length > 16
                  # http://forums.freebsd.org/showthread.php?t=14636
                  _div.bg_danger "UserID #{@user} is too long (max 16)"
                elsif @pmc !~ /^[0-9a-z-]+$/
                  _div.bg_danger "Unsafe PMC #{@pmc}"
                elsif @podling and @podling !~ /^[0-9a-z-]*$/
                  _div.bg_danger "Unsafe podling name #{@podling}"
                elsif not iclas.include? @email
                  _div.bg_danger "No ICLA on record for #{@email}"
                elsif not iclas[@email] == @name
                  _div.bg_danger "Name #{@name} does not match name on ICLA"
                elsif not pmcs.include? @pmc
                  _div.bg_danger "Unrecognized PMC name #{@pmc}"
                else

                  tobe = nil

                  # build the line to be added
                  line = "#{@user};#{@name};#{@email};#{@pmc};" +
                    "#{@pmc};#{Date.today.strftime('%m-%d-%Y')};yes;yes;no;"

                  # determine the requesting party and cc_list
                  @pmc =~ /([\w.-]+)/
                  requestor = $1
                  requestor.untaint
                  pmc_list = ASF::Committee.find(@pmc).mail_list
                  cc_list = ["private@#{pmc_list}.apache.org".untaint]
                  if requestor == 'incubator' and not @podling.empty?
                    if File.read("#{APMAIL_BIN}/.archives").include? "incubator-#{@podling}-private"
                      cc_list << "#{@podling}-private@#{pmc_list}.apache.org".untaint
                    else
                      cc_list << "private@#{@podling}.#{pmc_list}.apache.org".untaint
                    end
                    requestor = "#{@podling}@incubator".untaint
                  end
                  cc_list << "<#{@email}>".untaint # TODO: add @name RFC822-escaped

                  # build the mail to be sent
                  ASF::Mail.configure
                  mail = Mail.new do
                    from  "#{user.public_name} <#{user.id}@apache.org>"
                    return_path "root@apache.org"
                    to      "root@apache.org"
                    cc      cc_list
                  end

                  mail.subject "[FORM] Account Request - #{requestor}: #{@name}"

                  mail.body = <<-EOF.gsub(/^ {10}/, '').gsub(/(Vote reference:)?\n\s+\n/, "\n\n")
                    Prospective userid: #{@user}
                    Full name: #{@name}
                    Forwarding email address: #{@email}

                    Vote reference:
                      #{@votelink.to_s.gsub('mail-search.apache.org/pmc/', 'mail-search.apache.org/members/')}

                    #{@comments}

                    -- 
                    Submitted by https://#{ENV['HTTP_HOST']}#{ENV['REQUEST_URI'].split('?').first}
                    From #{`/usr/bin/host #{ENV['REMOTE_ADDR'].dup.untaint}`.chomp}
                    Using #{ENV['HTTP_USER_AGENT']}
                  EOF

                  Dir.mktmpdir do |tmpdir|
                    tmpdir.untaint

                    # Checkout the ACREQ directory
                    `#{SVN} co #{ACREQ} #{tmpdir}`

                    # Update the new-account-reqs file...
                    File.open("#{tmpdir}/new-account-reqs.txt", 'a') do |file|
                      file.puts(line)
                    end

                    # and commit the change ...
                    _h2 'Commit messages'
                    rc = _.system ['/usr/bin/svn',
                      ['--username', env.user, '--password', env.password],
                      'commit', "#{tmpdir}/new-account-reqs.txt",
                      '-m', "#{requestor} account request by #{user.id}"]

                    if rc == 0
                      mail.deliver!
                    else
                      tobe = 'that would have been '
                    end
                  end

                  # report on status
                  _h2 "New entry #{tobe}added:"
                  _pre line
                  _h2 "Mail #{tobe}sent:"
                  _pre.email mail.to_s
                end
              end
            end # of if _.post?
          end
        end
        # Add separate column for ICLA options
        _div.col_md_4 do
          unless _.post?
            _div.well.well_lg do
              if @iclas == 'all'
                _span 'Now showing all ICLAs ever received.  Click here to'
                _a 'show only ICLAs received recently', href: '?'
                _span '.'
              else
                _span 'Now showing only ICLAs received recently.  Click here to'
                _a 'choose from the full list of ICLA submitters', href: '?iclas=all'
                _span '.'
              end
            end
          end
        end
      end
    end
  end
end
