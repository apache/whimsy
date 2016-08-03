#!/usr/bin/ruby
#
#   Just for demo purposes at the moment.  Builds a properly formatted
#   and validated new-account-reqs.txt entry based on web input.  With
#   the proper browser and with jquery installed, this will do full client
#   side validation.  Server-side validation will also be done.
#
#   In demo mode, this script simply shows the formatted line that would
#   be added to the file and the email to be sent.  In non-demo mode, it
#   actually appends the line to the file and issue a svn commit, returns
#   the messages produced by the commit (if any) in the response, and
#   sends an email to root (copying the relevant pmc private list) of the
#   request.
#
# Prereqs:
#
#   * svn checkout of infra/infrastructure/trunk and foundation/officers
#   * Web server with the ability to run cgi (Apache httpd recommended)
#   * Ruby 1.8.x or later
#   * cgi-spa and mail gems ([sudo] gem install cgi-spa mail)
#   * (optional) jQuery http://code.jquery.com/jquery.min.js
#
# Installation instructions:
#_.post?
#  ruby submit-account-request.rb --install=/var/www
#
#    1) Specify a path that supports cgi, like public-html or Sites.
#    2) Tailor the paths and smtp settings in the generated
#       submit-account-request.cgi as necessary.
#    3) Download jQuery from the link above into either the directory
#       containing the CGI or in the DOCUMENT_ROOT for the web server
#
# Execution instructions:
#
#   Point your web browser at your generated cgi script.  For best results,
#   use a browser that implements HTML5 form validation.

require 'wunderbar'
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

# get up to date...
`#{SVN} cleanup #{INFRA}/acreq #{OFFICERS} #{APMAIL}/bin`
_.post?`#{SVN} revert -R #{INFRA}/acreq`
st?
unless `#{SVN} status -q #{INFRA}/acreq`.empty?
  raise "acreq/ working copy is dirty"
end
`#{SVN} update --ignore-externals #{INFRA}/acreq #{OFFICERS} #{APMAIL}/bin`

REQUESTS = "#{INFRA}/acreq/new-account-reqs.txt"

# grab the current list of PMCs from ldap
pmcs = `/usr/local/bin/list_unix_group.pl`.chomp.split("\n") - NON_PMC_UNIX_GROUPS

# grab the list of podling mailing lists from apmail
podlings = REXML::Document.new(
    Net::HTTP.get_response(URI.parse 'http://incubator.apache.org/podlings.xml').body
  ).root.elements.collect { |x| x.attributes['status'] == 'current' && x.attributes['resource'] }.select { |x| x }.sort

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
    _meta :charset => 'utf-8'
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
    
    if (Pathname(sf).dirname + 'jquery.min.js').exist?
      src = 'jquery.min.js'
    elsif (Pathname(dr) + 'jquery.min.js').exist?
      src = '/jquery.min.js'
    else
     src =  'https://ajax.googleapis.com/ajax/libs/jquery/1.6.2/jquery.min.js'
    end

    _script '', :src => src

    scriptSrc = <<-EOF
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
    EOF
    _script scriptSrc, :type => "text/javascript" 
  end

  _body do
    _form :method=>'post' do
      _fieldset do
        _legend 'ASF New Account Request'

        _div do
          _label 'User ID', :for=>"user"
          _input :name=>"user", :id=>"user", :autofocus => "autofocus",
            :type=>"text", :required => "required",
            :pattern => '^[a-z][-a-z0-9_]+$' # useridvalidationpattern dup
        end

        _div do
          _label 'Name', :for=>"name"
          _select :name=>"name", :id=>"name", :required => "required" do
            _option '', :value => ''
            iclas.invert.to_a.sort.each do |name, email|
              _option name, :value => name, 'data-email' => email
            end
          end
        end

        _div do
          _label 'Email', :for=>"email"
          _select :name=>"email", :id=>"email", :required => "required" do
            _option '', :value => ''
            iclas.to_a.sort_by {|email, name| email.downcase}.
              each do |email, name|
              _option email.downcase, :value => email, 'data-name' => name
            end
          end
        end

        _div do
          _label 'PMC', :for=>"pmc"
          _select :name=>"pmc", :id=>"pmc" do
            _option '', :value => ''
            pmcs.each do |pmc| 
              _option pmc, {:value => pmc}
            end
          end
        end

        _div do
          _label 'Podling', :for=>"podling"
          _select :name=>"podling", :id=>"podling" do
            _option '', :value => ''
            podlings.each do |podling| 
              _option podling, {:value => podling}
            end
          end
        end

        _div do
          _label 'Vote Link', :for=>"votelink"
          _input :name=>"votelink", :id=>"votelink", :type=>"text",
            :pattern => '.*://.*|.*@.*'
        end

        _div do
          _label 'Comments', :for=>"comments"
          _textarea "", :name=>"comments", :id=>"comments" 
        end

        _input :type=>"submit", :value=>"Submit"
      end
    end

    if _.post?
      # server side validation
      if pending.include? @email
        _div "Account request already pending for #{@email}", :class => 'error'
      elsif taken.include? @user
        _div "UserID #{@user} is not available", :class => 'error'
      elsif @user !~ /^[a-z][a-z0-9_]+$/ # useridvalidationpattern dup (disallow '-' in names because of INFRA-7390)
        _div "Invalid userID #{@user}", :class => 'error'
      elsif @user.length > 16
        # http://forums.freebsd.org/showthread.php?t=14636
        _div "UserID #{@user} is too long (max 16)", :class => 'error'
      elsif @pmc !~ /^[0-9a-z-]+$/
        _div "Unsafe PMC #{@pmc}", :class => 'error'
      elsif @podling and @podling !~ /^[0-9a-z-]*$/
        _div "Unsafe podling name #{@podling}", :class => 'error'
      elsif not iclas.include? @email
        _div "No ICLA on record for #{@email}", :class => 'error'
      elsif not iclas[@email] == @name
        _div "Name #{@name} does not match name on ICLA", :class => 'error'
      elsif not pmcs.include? @pmc
        _div "Unrecognized PMC name #{@pmc}", :class => 'error'
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
          if File.read("#{APMAIL}/bin/.archives").include? "incubator-#{@podling}-private"
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
            _pre exception.inspect, :class => 'error'
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
          command = "#{SVN} commit #{INFRA}/acreq/new-account-reqs.txt -m " + 
            "#{requestor} account request by #{submitter_id}".inspect
          _h2 'Commit messages'
          Open3.popen3(command) do |pin, pout, perr|
            [
              Thread.new do
                _p pout.readline.chomp, :class=>'stdout' until pout.eof?
              end,
              Thread.new do
                _p perr.readline.chomp, :class=>'stderr' until perr.eof?
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
        _pre mail.to_s, :class => 'email'
      end
    end

    unless _.post?
      _p do
        if query_string.has_key? 'fulllist'
          _span 'This page shows all ICLAs ever received.  Click here to'
          _a 'show only ICLAs received recently', :href => '?'
          _span '.'
        else
          _span 'This page shows only ICLAs received recently.  Click here to'
          _a 'choose from the full list of ICLA submitters', :href => '?fulllist=1'
          _span '.'
        end
      end
    end
  end
end

__END__
# Doesn't actually have any effect !?  The one in the .rb file has an effect.
$SAFE = 1

# tailor these lines as necessary
INFRA = '..'
APMAIL = '../../apmail'
OFFICERS = '../../foundation/officers'

# uncomment the next line if you have installed gems in a non-standard location
# ENV['GEM_PATH'] = '/prefix/install-dir'

require 'rubygems'
require 'mail'

# customize the delivery method
Mail.defaults do
  # probably will work out of the box on ASF hardware
  delivery_method :sendmail

### For comparison, here's how to connect to gmail
# delivery_method :smtp,
#   :address =>        "smtp.gmail.com",
#   :port =>           587, 
#   :domain =>         "apache.org",
#   :authentication => "plain",
#   :user_name =>      "username",
#   :password =>       "password",
#   :enable_starttls_auto => true
end

# this should be pretty self evident
DEMO_MODE = true

# potentially useful when installed on a personal machine
# ENV['REMOTE_USER'] ||= `/usr/bin/whoami`.chomp
