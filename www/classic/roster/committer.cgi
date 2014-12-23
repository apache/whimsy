#!/usr/bin/ruby1.9.1

require 'wunderbar'
require 'whimsy/asf'

exceptions = %w(hudson-jobadmin).map {|name| ASF::Committee.find name}

# location of pgp keys
COMMITTER_KEYS = "https://people.apache.org/keys/committer/%s.asc"

# extract committer email from uri
if ENV['REQUEST_URI'] =~ /committer\/(.+?)(\?|$)/
  ENV['QUERY_STRING'] = "email=#{CGI::escape($1)}@apache.org"
end

_json do
  person = ASF::Person.find_by_email(@email)
  if person
    _availid person.id
    _name person.public_name
    _emails person.all_mail
    _urls person.urls
    _committees person.committees.map(&:name)
    _member person.asf_member?
    _banned person.banned? if person.banned?
    _pgpkeys (person.pgp_key_fingerprints || [])
    _groups person.groups.map(&:name)
    _auth person.auth
  end
end

_text do
  person = ASF::Person.find_by_email(@email)
  if person
    _ "AvailId:    #{person.id}"
    _ "Member:     #{person.asf_member?}"
    if person.committees.empty?
      _ "Committees: -"
    else
      _ "Committees: #{person.committees.map(&:name).sort.join(' ')}"
    end
  end
end

_html do
  _head_ do
    @email = @email.strip.sub(/^mailto:/, '').strip if @email
    if @email.to_s =~ /(.*)@apache.org$/
      _title "Apache committer - #{$1}"
    else
      _title 'Apache email address lookup'
    end
    _meta charset: 'utf-8'
    _style %{
      h2 {margin-bottom: 0}
      table ul {margin: 0; padding: 0; list-style: none}
      table {border-spacing: 0 1em}
      td:first-child {text-align: right; padding: 0}
      td:first-child:after {content: ' \u2014'}
      td:last-child {border-left: solid 1px #000; padding: 0 0.5em}
      table {padding-left: 1.5em}
      .issue {color: red; font-weight:bold}
    }

    _script %q{
      function trim_email(e) {
        return e.replace(/^\s+/, '').replace(/\s+$/, '').replace(/^mailto:/, '');
      }
    }
  end

  _body? do
    # common banner
    _a href: 'https://whimsy.apache.org/' do
      _img title: "ASF Logo", alt: "ASF Logo", 
        src: "https://id.apache.org/img/asf_logo_wide.png"
    end

    # header based on URI and http method employed
    if @email.to_s.empty?
      # display form (and matching header) if no email was provided, or this
      # page was the result of a post (presumably from the form)
      _h1_ 'Apache email address lookup'

      _form method: 'post' do
        _input id: 'email', name: 'email', type: 'email', value: @email,
          onchange: 'value = trim_email(value);'
      end
    else
      # individual committer page
      _h2_ @email
    end

    unless @email.to_s.empty?
      # individual committer page - start by looking up email address
      person = ASF::Person.find_by_email(@email)

      if person
        _table do
	  if person.id == 'notinavail'
            _tr_ do
	      _td 'name'
	      _td ASF::ICLA.find_by_email(@email).name
            end
	  else
            # committer's availid - but only if the email is non apache.org
            unless @email =~ /@apache.org$/
              _tr_ do
                _td 'id'
                _td person.id
              end
            end

            # display name (typically from iclas.txt)
            _tr_ do
              _td 'name'
              if person.icla
                _td person.public_name
              else
                _td person.public_name || 'Not Found', class: 'issue', 
                  title: 'No ICLA on file'
              end
            end

            # membership information (from members.txt)
            if person.asf_member? or person.icla
              _tr_ do
                _td 'ASF Member'
                _td person.asf_member?
              end
            end

            # personal urls
            unless person.urls.empty?
              _tr_ do
                _td 'Personal URL'
                _td do
		  _ul do
		    person.urls.each do |url|
		      _li {_a url, href: url}
		    end
		  end
                end
              end
            end

            # if user is banned, flag this
            if person.banned?
              _tr_ do
                _td 'login'
                _td 'disabled', class: 'issue'
              end
            end

            # list of committees that this committer is a member of (from ldap)
            unless (person.committees-exceptions).empty?
              _tr_ do
                _td 'Committees'
                _td do
	          _ul do
	            person.committees.sort_by(&:name).each do |committee|
                      next if exceptions.include? committee
                      name = committee.name 
		      _li do
                        if person.groups.any? {|group| group.name == name}
                          _a name, href: "../committee/#{name}"
                        else
                          if committee.members.empty?
                            _a name, href: "../committee/#{name}",
                              title: "not in corresponding LDAP group"
                          else
                            _a name, href: "../committee/#{name}",
                              title: "not in corresponding LDAP group",
                              class: 'issue'
                          end
                        end
                        _ '(chair)' if committee.chair == person
                      end
		    end
		  end
	        end
              end
            end

            # list of groups that this committer is a member of (from ldap)
            groups =  person.groups.select do |group| 
              not person.committees.any? {|cmt| cmt.name == group.name}
            end

            unless groups.empty?
              _tr_ do
                _td 'Groups'
                _td do
	          _ul do
	            groups.sort_by(&:name).each do |group|
		      _li group.name
		    end
		  end
	        end
              end
            end

            # list of other authorities that this individual has
            # (from asf-authorization-template)
            auth = person.auth
            exceptions.each do |exception| 
              auth << exception.name if person.committees.include? exception
            end
            unless auth.empty?
              _tr_ do
                _td 'Auth'
                _td do
	          _ul do
	            auth.sort.each do |group|
		      _li group
		    end
		  end
	        end
              end
	    end

            if person.pgp_key_fingerprints
              require 'net/https'
              person.id.untaint if person.id =~ /^\w+/
              uri = URI.parse(COMMITTER_KEYS % person.id)
              _tr_ do
                _td 'PGP Key'
                found = false
	        http = nil
                begin
		  http = Net::HTTP.new(uri.host, uri.port)
		  http.use_ssl = true if uri.scheme == 'https'
		  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
		  found = true if http.head(uri.path).code == '200'
		ensure
		  http.finish if http and http.started?
		end
                _td do
                  _ul do
                    person.pgp_key_fingerprints.each do |pgpkey|
		      if found
                        _li {_a pgpkey, href: uri}
		      else
                        _li pgpkey
		      end
                    end
                  end
                end
              end
            end

            if ASF::Person.new($USER).asf_member?
              emails = person.all_mail
              emails.delete "#{person.id}@apache.org"
              unless emails.empty?
                _tr_ do
                  _td 'Email addresses'
                  _td do
	            _ul do
	              emails.sort.each do |email|
                        if person.obsolete_emails.include? email
		          _li {_del email}
                        else
		          _li email
                        end
		      end
		    end
		  end
                end
	      end

              if person.asf_member?
                if person.members_txt
                  _tr_ do
                    _td 'members.txt'
                    _td { _pre " *) " + person.members_txt.strip }
                  end
                end
              elsif person.member_nomination
                _tr_ do
                  _td do
                   _a 'nominated-members', href: 'https://svn.apache.org/repos/private/foundation/Meetings/20130521/nominated-members.txt'
                  end
                  _td { _pre person.member_nomination.chomp }
                end
              elsif person.member_watch
                _tr_ do
                  _td do
                   _a 'potential-member-watch', href: 'https://svn.apache.org/repos/private/foundation/potential-member-watch-list.txt'
                  end
                  _td { _pre person.member_watch.chomp }
                end
              end
            end
	  end
        end
      else
        _p "not found"
      end
    end

    # additional links (note some are member only)
    _h2_ 'Sources'
    _ul do
      _li do
        _a 'id.apache.org', href: 'https://id.apache.org/'
      end
      if ASF::Person.new($USER).asf_member?
        _li do
          _a 'members.txt', href: 'https://svn.apache.org/repos/private/foundation/members.txt'
        end
        _li do
          _a 'iclas.txt', href: 'https://svn.apache.org/repos/private/foundation/officers/iclas.txt'
        end
        _li do
          _a 'asf-authorization-template', href: 'https://svn.apache.org/repos/infra/infrastructure/trunk/subversion/authorization/asf-authorization-template'
        end
      end
    end
  end
end
