#!/usr/bin/env ruby
PAGETITLE = "Apache Account Submission Helper Form" # Wvisible:infra accounts
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'wunderbar/jquery'
require 'whimsy/asf/rack'
require 'whimsy/asf'
require 'mail'
require 'date'

user = ASF::Auth.decode(env = {})
unless user.asf_member? or ASF.pmc_chairs.include? user
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

ICLAS = ASF::SVN.svnpath!('officers', 'iclas.txt')

# get up to date data...
requests, err = ASF::SVN.svn('cat', ASF::SVN.svnpath!('acreq', 'new-account-reqs.txt'), {env: env})

iclas_txt,err = ASF::SVN.svn('cat', ICLAS, {env: env}).force_encoding('utf-8')

# grab the current list of PMCs from ldap
pmcs = ASF::Committee.pmcs.map(&:name).sort

# grab the current list of nonPMCs with member lists from ldap
nonpmcs = ASF::Committee.nonpmcs.map(&:name).
  select {|name| ASF::Project.find(name).hasLDAP?}

# grab the list of active podlings
podlings = ASF::Podling.list.select {|podling| podling.status == 'current'}.
  map(&:name).sort

# combined list of pmcs and projects
projects = (pmcs + podlings + nonpmcs).uniq.sort

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
  log, err = ASF::SVN.svn(['log', '--incremental', '-q', "-l#{count}"], ICLAS, {revision: 'HEAD:0', env: env})
  oldrev = log.split("\n")[-1].split()[0][1..-1].to_i
  diff, err = ASF::SVN.svn('diff', ICLAS, {revision: "#{oldrev}:HEAD", env: env})
  iclas = Hash[*diff.scan(/^[+]notinavail:.*?:(.*?):(.*?):Signed CLA/).flatten.reverse]
end

# grab the list of userids that have been assigned (for validation purposes)
taken = (ASF::ICLA.availids_taken + ASF::Mail.qmail_ids).uniq

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
      input:invalid {border: solid 3px #F00}
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

        // allow selected fields to be set based on parameters passed
        if (#{@user.to_s.inspect} != '')
          $('#user').val(#{@user.to_s.inspect});
        $('#email').val(#{@email.to_s.inspect}).trigger('change');
        var project = #{(@project || @podling || @pmc).to_s.inspect};
        $('#project').val(project).trigger('change').
          attr('required', 'required');
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
        '/roster' => 'Whimsy Roster Tool',
        'https://cwiki.apache.org/confluence/display/INFRA/Reference' => 'Infra Reference Documentation',
        'https://infra.apache.org/managing-committers.html' => 'Infra How To Create New Account Docs'
      },
      helpblock: -> {
        _p %{
          This page builds a properly formatted and validated new-account-reqs.txt entry based
          on your input below.  Does both full client validation and Server-side validation.
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
                _div.col_sm_6 do
                  _input.form_control name: "user", id: "user", autofocus: true,
                    type: "text", required: true,
                    pattern: '^[a-z][a-z0-9]{2,}$' # useridvalidationpattern dup
                end
                _div.col_md_4 do
                  _ 'Alphanumeric only, starting with alpha, minimum 3 chars'
                end
              end

              _div.form_group do
                _label.control_label.col_sm_2 'Name', for: "name"
                _div.col_sm_6 do
                  _select.form_control name: "name", id: "name", required: true do
                    _option value: ''
                    iclas.invert.to_a.sort.each do |name, email|
                      _option name, value: name, data_email: email
                    end
                  end
                end
                _div.col_md_4 do
                  if @iclas == 'all'
                    _ 'Showing all ICLAs ever received.'
                    _br
                    _a 'Show only ICLAs received recently', href: '?'
                  else
                    _ 'Showing only ICLAs received recently.'
                    _br
                    _a 'Show the full list of ICLAs submitted', href: '?iclas=all'
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
                _label.control_label.col_sm_2 'Project', for: "project"
                _div.col_sm_10 do
                  _select.form_control name: "project", id: "pmc" do
                    _option value: ''
                    projects.each do |project| 
                      _option project, value: project
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
                _div.col_sm_offset_2.col_sm_1 do
                  _input.btn.btn_default type: "submit", value: "Submit"
                end
                _div.col_md_9 do
                  _ 'N.B. The email is copied to root, secretary, project (or operations if none) and the account subject. It includes the comment field.'
                end
              end
            end

            # If making a request, validate, checkin, and display results
            if _.post?
              _div.well.well_lg do
                abort = true

                # server side validation
                if pending.include? @email
                  _div.bg_danger "Account request already pending for #{@email}"
                elsif taken.include? @user
                  _div.bg_danger "UserID #{@user} is not available"
                elsif @user !~ /^[a-z][a-z0-9]{2,}$/ # useridvalidationpattern dup (disallow '-' in names because of INFRA-7390)
                  _div.bg_danger "Invalid userID #{@user}"
                elsif @user.length > 16
                  # https://forums.freebsd.org/showthread.php?t=14636
                  _div.bg_danger "UserID #{@user} is too long (max 16)"
                elsif not iclas.include? @email
                  _div.bg_danger "No ICLA on record for #{@email}"
                elsif not iclas[@email] == @name
                  _div.bg_danger "Name #{@name} does not match name on ICLA"
                elsif @project.empty?
                  abort = false
                elsif @project !~ /^[0-9a-z-]+$/
                  _div.bg_danger "Unsafe Project #{@project}"
                elsif not projects.include? @project
                  _div.bg_danger "Unrecognized Project name #{@project}"
                else
                  abort = false
                end

                unless abort
                  # determine pmc and podling from project; compute list
                  # of groups the individual is to be added to
                  if podlings.include? @project
                    @pmc = 'incubator'
                    @podling = @project
                    groups = "#@pmc,#@podling"
                  elsif @project.empty?
                    @pmc = nil
                    @podling = nil
                    groups = nil
                  else
                    @pmc = @project
                    @podling = nil
                    groups = @pmc
                  end

                  tobe = nil

                  # build the line to be added
                  line = "#{@user};#{@name};#{@email};#{groups};" +
                    "#{@pmc};#{Date.today.strftime('%m-%d-%Y')};yes;yes;no;"

                  # determine the requesting party and cc_list
                  if @project.empty?
                    cc_list = ["operations@apache.org"]
                    requestor = user.id.untaint
                  else
                    pmc_list = ASF::Committee.find(@pmc).mail_list
                    cc_list = ["private@#{pmc_list}.apache.org".untaint]
                    requestor = @pmc[/([\w.-]+)/, 1].untaint
                  end

                  if requestor == 'incubator' and not @podling.to_s.empty?
                    cc_list << "private@#{@podling}.#{pmc_list}.apache.org".untaint
                    requestor = "#{@podling}@incubator".untaint
                  end

                  cc_list << "#{@name} <#{@email}>".untaint
                  cc_list << "secretary@apache.org"

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

                  msg = "#{@user} account request by #{user.id} for #{requestor}"
                  rc = ASF::SVN.update(ASF::SVN.svnpath!('acreq', 'new-account-reqs.txt'), msg, env, _) do |dir, input|
                    _h2 'Commit messages'
                    input + line + "\n"
                  end
                  if rc == 0
                    mail.deliver!
                  else
                    tobe = 'that would have been '
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
      end
    end
  end
end
