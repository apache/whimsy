#!/usr/bin/ruby1.9.1
require 'wunderbar'
require 'yaml'

DOCTYPES = %w{icla grant ccla nda other}

_html do
  _head_ do
    _title 'worklist'
    _link rel: 'stylesheet', type: "text/css", href: "worklist.css"
    _script src: "jquery-1.7.2.min.js"
    _script src: 'worklist.js'
  end

  _body? do

    _pre do
      _ `date` + "\n"
    end

    if `which svn`.empty?
      _h2_.warn 'Unable to locate svn'
      _p 'Search PATH used:'
      _ul do
        ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
          _li { _code path }
        end
      end
    end

    begin
      begin
        require './local_paths'
        DOCTYPES.insert(-2, 'mem') if defined?(MEETING)
      rescue
        _h2_ 'Syntax error in local_paths.yml'
        raise 
      end

      files = []
      ENV['LANG']||="en_US.UTF-8"
      if defined?(MEETING)
        IO.popen("svn st #{FOUNDATION}/members.txt").each do |line|
          files << line.sub(FOUNDATION, 'foundation')
        end
        IO.popen("svn st #{MEETING}").each do |line|
          files << line.sub(MEETING, 'meeting')
        end
      end
      IO.popen("svn st #{OFFICERS}").each do |line|
        files << line.sub(OFFICERS, 'officers')
      end
      IO.popen("svn st #{DOCUMENTS}").each do |line| 
        files << line.sub(DOCUMENTS, 'documents')
      end

      message = 'Faxes received'

      if File.exist? PENDING_YML
        pending = YAML.load(open(PENDING_YML))
        if pending.size == 1
          pending = pending.first
          if pending['doctype'] == 'icla'
            message = "ICLA from #{pending['realname']}"
          elsif pending['doctype'] == 'ccla'
            message = "CCLA from #{pending['company']}"

            unless pending['employees'].nil? or pending['employees'].empty?
              message += " for "
              message += pending['employees'].strip.gsub(/\s*\n\s*/, ', ')
            end
          elsif pending['doctype'] == 'grant'
            message = "Grant from #{pending['from']}"
          elsif pending['doctype'] == 'mem'
            message = "Membership Application from #{pending['realname']}"
          elsif pending['doctype'] == 'nda'
            message = "NDA for #{pending['realname']}"
          end
        end
      end

      files.reject! {|f| f=~ /\/(activity|pending|completed)\.yml\s*$/}
      unless files.empty? and !File.exist?(PENDING_YML)
        _h2_ 'Pending'
        files.each {|line| _pre line.strip.sub(/\s+/,' ')}
        pending = YAML.load(open(PENDING_YML)) rescue []
        pending.each {|vars| _pre "@ #{vars['email']}" if vars['email']}
        _form.buttons target: 'viewport', action: 'file.cgi', method: 'post' do
          _input name: 'message', id: 'message', type: 'hidden',
            'data-value' => message
          _input type: 'submit', name: 'action', value: 'Edit CC'
          _input type: 'submit', name: 'action', value: 'Cleanup'
          _input type: 'submit', name: 'action', value: 'Commit'
        end
      end

      files = []
      Dir.chdir("#{RECEIVED}") do
        Dir["*"].sort_by {|name| File.stat(name.untaint).mtime}.each do |file|
          next if %w{README deadletter archives}.include? file
          next if %w{pending.yml completed.yml activity.yml}.include? file
          next if file =~ /^to_\w+$/
          if File.directory? file
            next if Dir.entries(file).reject {|name| name=~/^\./}.empty?
          end
          File.chmod 0644, file if file =~ /\.pdf$/
          files << file
        end
      end

      _h2_ 'Work List'
      if files.empty?
        _p.worklist! { _i 'Empty' }
      else
        _ul.worklist! do
          files.each do |file|
            _li do
              ondisk = File.join(RECEIVED,file)
              file += '/' if File.directory? ondisk
              _a file, 'data-mtime' => (File.stat(ondisk).mtime.to_i rescue nil)
            end
          end
        end
      end

      _div_.classify! do
        _h2_ 'Classification'

        _form.doctype! target: 'viewport', action: 'file.cgi', method: 'post' do
          _table_ do
            _tr do
              DOCTYPES.each do |doctype|
                _td align: 'center' do
                  _input type: 'radio', name: 'doctype', value: doctype
                end
              end
            end
            _tr do
              DOCTYPES.each do |doctype|
                _td doctype, align: 'center'
              end
            end
          end

          _input name: 'source', id: 'source', type: 'hidden'

          _table_ id: 'icla-form' do
            _tr do
              _td.label 'Real Name'
              _td.input do
                _input name: 'realname', id: 'realname', type: 'text'
              end
            end
            _tr do
              _td.label 'Public Name'
              _td.input do
                _input name: 'pubname', id: 'pubname', type: 'text'
              end
            end
            _tr do
              _td.label 'E-mail'
              _td do 
                _input name: 'email', id: 'email', type: 'email'
              end
            end
            _tr do
              _td.label 'File Name'
              _td.input do
                _input name: 'filename', id: 'filename', type: 'text'
              end
            end
          end

          _div_ id: 'nda-form' do
            _table do
              _tr do
                _td do
                  _label 'Name', for: 'nname'
                end
                _td do
                  _input type: :text, name: 'nname', id: 'nname'
                end
              end

              _tr do
                _td do
                  _label 'ASF ID', for: 'nid'
                end
                _td do
                  _input type: :text, name: 'nid', id: 'nid'
                end
              end

              _tr do
                _td.label 'EMail'
                _td.input do
                  _input name: 'nemail', id: 'nemail', type: 'email'
                end
              end

              _tr do
                _td.label 'File Name'
                _td.input do
                  _input name: 'nfilename', id: 'nfilename', type: 'text'
                end
              end
            end
          end

          _div id: 'mem-form' do
            if defined?(MEETING)
              received = open("#{MEETING}/memapp-received.txt").read
            else
              received = ''
            end

            _table do
              _tr do
                _td do
                  _label 'Public Name', for: 'mpname'
                end
                _td do
                  _select id: 'mavailid', name: 'mavailid' do
                    pattern = /^\w+\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(.*)\n/
                    _option value: '', selected: true
                    options = []
                    received.scan(pattern) do |apply, mail, karma, id, name|
                      next unless apply=='no'
                      options << [ name.strip, id ]
                    end
                    options.sort.each do |name, id|
                      _option name, value: id
                    end
                  end
                end
              end
        
              _tr do
                _td do
                  _label 'Full Name', for: 'mfname'
                end
                _td do
                  _input type: :text, name: 'mfname', id: 'mfname'
                end
              end
        
              _tr do
                _td do
                  _label 'Address', for: 'maddr'
                end
                _td do
                  _textarea rows: 5, name: 'maddr', id: 'maddr'
                end
              end
                
              _tr do
                _td do
                  _label 'Country', for: 'mcountry'
                end
                _td do
                  _input type: :text, name: 'mcountry', id: 'mcountry'
                end
              end
                
              _tr do
                _td do
                  _label 'Telephone', for: 'mtele'
                end
                _td do
                  _input type: :text, name: 'mtele', id: 'mtele'
                end
              end
                
              _tr do
                _td do
                  _label 'Fax', for: 'mfax'
                end
                _td do
                  _input type: :text, name: 'mfax', id: 'mfax'
                end
              end
                
              _tr do
                _td do
                  _label 'E-Mail', for: 'memail'
                end
                _td do
                  _input type: :email, name: 'memail', id: 'memail'
                end
              end
                
              _tr do
                _td do
                  _label 'File Name', for: 'mfilename'
                end
                _td do
                  _input type: :text, name: 'mfilename', id: 'mfilename'
                end
              end
            end
          end

          _div_ id: 'grant-form' do
            _table do
              _tr do
                _td.label 'From'
                _td do
                  _input name: 'from', type: 'text'
                end
              end
              _tr do
                _td.label 'For'
                _td do
                  _textarea name: 'description', rows: 5
                end
              end
              _tr do
                _td.label 'Signed By'
                _td do
                  _input name: 'gname', id: 'gname', type: 'text'
                end
              end
              _tr do
                _td.label 'E-mail'
                _td do
                  _input name: 'gemail', id: 'gemail', type: 'email'
                end
              end
              _tr do
                _td.label 'File Name'
                _td.input do
                  _input name: 'gfilename', type: 'text'
                end
              end
            end
          end

          _table_ id: 'ccla-form' do
            _tr do
              _td.label 'Corporation'
              _td.input do
                _input name: 'company', id: 'company', type: 'text'
              end
            end
            _tr do
              _td.label 'Product'
              _td.input do
                _input name: 'product', id: 'product', type: 'text'
              end
            end
            _tr do
              _td.label 'Contact'
              _td do
                _input name: 'contact', id: 'contact', type: 'text'
              end
            end
            _tr do
              _td.label 'E-mail'
              _td do
                _input name: 'cemail', id: 'cemail', type: 'email'
              end
            end
            _tr do
              _td.label 'Employees'
              _td { _textarea name: 'employees', rows: 5 }
            end
            _tr do
              _td.label 'File Name'
              _td.input do
                _input name: 'cfilename', type: 'text'
              end
            end
          end

          _input name: 'replaces', id: 'replaces', type: 'hidden'

          _div_.buttons!.buttons do
            _input type: 'submit', value: 'File'
            _input type: 'submit', name: 'action', value: 'Cancel'
          end

          _div_.buckets!.buttons do
            _fieldset do
              _legend 'Do:'
              _input type: 'submit', name: 'dest', value: 'burst'
              _input type: 'submit', name: 'dest', value: 'flip'
              _input type: 'submit', name: 'dest', value: 'restore'
              _input type: 'submit', name: 'dest', value: 'rotate right'
              _input type: 'submit', name: 'dest', value: 'rotate left'
            end
            _fieldset do
              _legend 'File:'
              _input type: 'submit', name: 'dest', value: 'operations'
              _input type: 'submit', name: 'dest', value: 'dup'
              _input type: 'submit', name: 'dest', value: 'junk'
              _input type: 'submit', name: 'dest', value: 'incomplete'
              _input type: 'submit', name: 'dest', value: 'unsigned'
            end
          end

          _table id: 'icla2-form' do
            _tr do
              _td.label 'User ID'
              _td.input do
                _input name: 'user', id: 'user', type: 'text'
              end
            end
            _tr do
              _td.label 'PMC'
              _td.input do
                _input name: 'pmc', id: 'pmc', type: 'text'
              end
            end
            _tr do
              _td.label 'Podling'
              _td.input do
                _input name: 'podling', id: 'podling', type: 'text'
              end
            end
            _tr do
              _td.label 'Vote Link'
              _td.input do
                _input name: 'votelink', id: 'votelink', type: 'text'
              end
            end
          end

          _table id: 'grant2-form' do
            _tr do
              _td.label 'PMC'
              _td.input do
                _input name: 'ggmc', id: 'gpmc', type: 'text'
              end
            end
            _tr do
              _td.label 'Podling'
              _td.input do
                _input name: 'gpodling', id: 'gpodling', type: 'text'
              end
            end
          end

          _table id: 'ccla2-form' do
            _tr do
              _td.label 'PMC'
              _td.input do
                _input name: 'cpmc', id: 'cpmc', type: 'text'
              end
            end
            _tr do
              _td.label 'Podling'
              _td.input do
                _input name: 'cpodling', id: 'cpodling', type: 'text'
              end
            end
          end
        end
      end

      _h2_ 'Links'
      _ul do
        _li do
          _a 'Response time', target: 'viewport',
            href: 'https://whimsy.apache.org/secretary/response-time'
        end
        _li do
          _a 'Mail Search', href: 'https://mail-search.apache.org/',
            target: 'viewport'
        end
        _li do
          query = ''

          if File.exist? COMPLETED_YML
            last = YAML.load(File.read COMPLETED_YML).last
            params = {}
            %w{email user pmc podling votelink}.each do |name|
              params[name] = last[name] if last[name]
            end
            unless params.empty?
              query = '?' + params.
                map {|name,value| "#{name}=#{CGI.escape value}"}.join('&')
            end
          end

          _a 'New Account', target: 'viewport',
            href: 'https://id.apache.org/acreq/members/' + query
        end
        _li do
          _a 'Committers by id', target: 'viewport',
            href: 'http://people.apache.org/committer-index.html'
        end
        _li do
          _a 'Documents', target: 'viewport',
            href: 'https://svn.apache.org/repos/private/documents/'
        end
        _li do
          _a 'ICLA lint', target: 'viewport',
            href: 'https://whimsy.apache.org/secretary/icla-lint'
        end
        _li do
          _a 'Public names', target: 'viewport',
            href: 'https://whimsy.apache.org/secretary/public-names'
        end
        _li do
          _a 'Board subscriptions', target: 'viewport',
            href: 'https://whimsy.apache.org/board/subscriptions/'
        end
        _li do
          _a 'Mail aliases', target: 'viewport',
            href: 'https://id.apache.org/info/MailAlias.txt'
        end
        _li do
          _a 'Member list', target: 'viewport',
            href: 'https://svn.apache.org/repos/private/foundation/members.txt'
        end
        _li do
          _a 'How to use this tool', href: 'HOWTO.html',
            target: 'viewport'
        end

        if File.exist? '/var/tools/secretary/secmail'
          _li {_p {_hr}}
          _li {_a 'Upload email', href: 'upload', target: 'viewport'}
        end
      end
    end
  end
end
