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
export = 
  'https://svn.apache.org/repos/infra/websites/cms/webgui/content/export.json'
PROJ_PAT = '[a-z0-9_.-]+'

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
          pattern: "^#{PROJ_PAT}$"

        _h3_ 'Where to send commit notifications'
        _input type: 'text', name: 'clist', value: @clist || 'commits'
        _ '@'
        _select name: 'pmc' do
          pmcs.sort.each do |pmc| 
            _option pmc, selected: (pmc == @pmc)
          end
        end
        _ '.apache.org'

        _h3_ 'Where to send patches received'
        _input type: 'text', name: 'plist', value: @plist || 'dev'
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

        _h3_ 'Notes'
        _textarea name: 'message', cols: 70

        _input_ type: 'submit', value: 'Submit Request'
      end
    end

    if _.post?
      Dir.chdir '/var/tools/infra/cmsreq'
      `svn update --non-interactive`

      # https://svn.apache.org/repos/infra/infrastructure/trunk/docs/services/cms.txt
      error = nil
      error ||= 'Invalid project name'  unless @project =~ /^#{PROJ_PAT}$/
      error ||= 'Invalid build type' unless BUILD_TYPES.include? @build_type

      unless ASF::Mail.lists.include? "#{@pmc}-#{@clist}"
        error ||= "Mail list #{@clist}@#{@pmc}.apache.org doesn't exist"
      end

      unless ASF::Mail.lists.include? "#{@pmc}-#{@plist}"
        error ||= "Mail list #{@plist}@#{@pmc}.apache.org doesn't exist"
      end

      websites = JSON.load(http_get(export).body)
      if websites.values.include? @source
        error = "#{@source} is already using the CMS"
      elsif websites.keys.include? @project
        if @source.include? 'incubator' or not websites[@project].include? 'incubator' 
          error = "Project name #{@project} is already in use by #{websites[@project]}"
        end
      end

      begin
        @source += '/' unless @source.end_with? '/'
        @source.chomp! 'trunk/'
        if not @source.start_with? 'https://svn.apache.org/'
          error ||= "source URL must be from ASF SVN"
        elsif http_get(URI.parse(@source) + 'trunk/content/').code != '200'
          error ||= "trunk/content directory not found in source URL"
        elsif @pmc=='incubator' 
          if not @source.include? @project.gsub('-','/')
            error ||= "#{@project.gsub('-','/')} not found in source URL"
          elsif @build_type != 'standard'
            error ||= "Incubator podlings must use the standard build system"
          end
        end

        required = []
        required << 'trunk/lib/view.pm' if @build_type == 'standard'
        required << 'trunk/build.xml' if @build_type == 'ant'
        required << 'trunk/build_cms.sh' if @build_type == 'shell'
        required << 'trunk/pom.xml' if @build_type == 'maven'
        required << 'pom.xml' if @build_type == 'maven'

        if not required.any? {|file| http_get("#{@source}#{file}").code=='200'}
          error = "Missing #{@source}#{required.first}"
        end
      rescue Exception => exception
        error = "Exception processing URL: #{exception}"
      end

      cmsreq = "#{@project.untaint}.json"
      if File.exist? cmsreq
        error << "Already submitted: #{@project}"
      end

      if error
        _h2_ 'Error'
        _p error
      else
        _h2_ "Submitted request"

        # format request
        vars = {
          source: @source,
          project: @project,
          commit_list: "#{@clist}@#{@pmc}.apache.org",
          patch_list: "#{@plist}@#{@pmc}.apache.org",
          build: @build_type
        }
        vars[:message] = @message unless @message.empty?
        request = JSON.pretty_generate(vars) + "\n"
        _pre request

        # commit it
        File.open(cmsreq, 'w') { |file| file.write request }
        _.system(['svn', 'add', '--', cmsreq])
        _.system [
	  'svn', 'commit', ['--no-auth-cache', '--non-interactive'],
          '-m', "#{@project} CMS request by #{$USER} via " + 
            env['SERVER_ADDR'],
	  (['--username', $USER, '--password', $PASSWORD] if $PASSWORD),
          '--', cmsreq
        ]
      end
    end

    # guess where commit emails should go
    commits = {}
    patches = {}
    %w(dev commits).each do |suffix|
      ASF::Mail.lists.grep(/-#{suffix}$/).sort.each do |list|
        commits[list.chomp("-#{suffix}")] = suffix
        patches[list.chomp("-#{suffix}")] ||= suffix
      end
    end

    _script_ "commits = #{JSON.pretty_generate(commits)}"
    _script_ "patches = #{JSON.pretty_generate(patches)}"

    SRC_PAT = 
      %r{https://svn.apache.org/repos/asf/(#{PROJ_PAT})/?(#{PROJ_PAT})?/.}

    _script %{
      // when source changes, set project and list
      $('input[name=source]').change(function() {
        if ($(this).val().indexOf('http:') == 0) {
          $(this).val($(this).val().replace('http:', 'https:'));
        }

        var match = #{SRC_PAT.inspect}.exec($(this).val());
        if (match) {
          $('select[name=pmc]').val(match[1]);
          if (commits[match[1]]) $('input[name=clist]').val(commits[match[1]]);
          if (patches[match[1]]) $('input[name=plist]').val(patches[match[1]]);
          if (match[2]) {
            if (match[1] == 'incubator') {
              $('input[name=project]').val(match[2]);
            } else if (match[2] == 'site') {
              $('input[name=project]').val(match[1]);
            } else {
              $('input[name=project]').val(match[1]+'-'+match[2]);
            }
            var clist = commits[match[1]+'-'+match[2]];
            if (clist) $('input[name=clist]').val(match[2]+'-'+clist);
            var plist = patches[match[1]+'-'+match[2]];
            if (plist) $('input[name=plist]').val(match[2]+'-'+plist);
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

