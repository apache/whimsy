#!/usr/bin/ruby1.9.1
require 'wunderbar'
require '/var/tools/asf'
require 'shellwords'

user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user or $USER=='ea'
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

BUILD_TYPES = %w(standard maven ant forrest shell)
pmcs = ASF::Committee.list.map(&:mail_list)

_html do

  _head_ do
    _title 'ASF CMS Request'
    _script src: '/jquery-min.js'
    _style %{
      textarea, .mod, label {display: block}
      input, select[name=build_type] {margin-left: 2em}
      input[type=submit] {display: block; margin: 1em 0 0 0}
      legend {background: #141; color: #DFD; padding: 0.4em}
      input[type=text] {width: 9em}
      input[type=url] {width: 30em}
    }
  end

  _body? do
    _form method: 'post' do
      _fieldset do
        _legend 'ASF CMS Request'

        _h3_ 'Source URL'
        _input type: 'url', name: 'source', required: true,
          value: @source || 'https://svn.apache.org/repos/asf/'

        _h3_ 'Project Name'
        _input type: 'text', name: 'project', required: true, value: @project,
          pattern: '^\w[-\w]+$'

        _h3_ 'Commits list'
        _input type: 'text', name: 'list', value: @list || 'commits'
        _ '@'
        _select name: 'pmc' do
          pmcs.sort.each do |pmc| 
            _option pmc, selected: (pmc == @pmc)
          end
        end
        _ '.apache.org'

        _h3_ 'Build Type'
        _select name: 'build_type' do
          BUILD_TYPES.each do |type| 
            _option type, selected: (type == @build_type)
          end
        end

        _input_ type: 'submit', value: 'Submit Request'
      end
    end

    if _.post?
      error = nil
      error ||= 'Invalid project name'  unless @project =~ /^\w[-\w]+$/
      error ||= 'Invalid build type' unless BUILD_TYPES.include? @build_type

      unless ASF::Mail.lists.include? "#{@pmc}-#{@list}"
        error ||= "Mail list #{@list}@#{@pmc}.apache.org doesn't exist"
      end

      begin
        @source += '/' unless @source.end_with? '/'
        @source.chomp! 'trunk/'
        if not @source.start_with? 'https://svn.apache.org/'
          error ||= "source URL must be from ASF SVN"
        elsif http_get(URI.parse(@source) + 'trunk/content/').code != '200'
          error ||= "trunk/content directory not found in source URL"
        elsif @pmc=='incubator' and not @source.include? @project.gsub('-','/')
          error ||= "#{@project.gsub('-','/')} not found in source URL"
        end
      rescue Exception => exception
        error = "Exception processing URL: #{exception}"
      end

      if error
        _h2_ 'Error'
        _p error
      else
        _h2_ 'Request that would be submitted if this application were complete'
        vars = {
          source: @source,
          project: @project,
          list: "#{@list}@#{@pmc}.apache.org",
          build: @build_type
        }
        vars.each {|name,value| vars[name] = Shellwords.shellescape(value)}
        request = vars.map {|name,value| "#{name}=#{value}\n"}.join
        _pre request
      end
    end

    # guess where commit emails should go
    commits = {}
    %w(dev commits).each do |suffix|
      ASF::Mail.lists.grep(/-#{suffix}$/).sort.each do |list|
        commits[list.chomp("-#{suffix}")] = suffix
      end
    end

    _script_ "commits = #{JSON.pretty_generate(commits)}"

    pattern = %r{https://svn.apache.org/repos/asf/(\w+)/?(\w+)?(/|$)}
    _script %{
      // when source changes, set project and list
      $('input[name=source]').change(function() {
        var match = #{pattern.inspect}.exec($(this).val());
        if (match) {
          $('select[name=pmc]').val(match[1]);
          if (commits[match[1]]) $('input[name=list]').val(commits[match[1]]);
          if (match[2]) {
            $('input[name=project]').val(match[1]+'-'+match[2]);
            var list = commits[match[1]+'-'+match[2]];
            if (list) $('input[name=list]').val(match[2]+'-'+list);
          } else {
            $('input[name=project]').val(match[1]);
          }
        }
      });

      // place cursor at end of source url
      $('input[name=source]').focus(function() {
        var value = $(this).val();
        this.setSelectionRange(value.length, value.length);
      }).focus();
    }
  end
end

require 'net/http'
def http_get(uri)
  uri = URI.parse(uri) if String === uri
  uri.host.untaint if uri.host =~ /^\w+[.]apache[.]org$/
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme=='https') do |http|
    http.request Net::HTTP::Get.new uri.request_uri
  end
end

