#!/usr/bin/ruby1.9.1
require 'wunderbar'
require '/var/tools/asf'
require 'shellwords'


require 'net/http'
def http_get(uri)
  uri = URI.parse(uri) if String === uri
  uri.host.untaint if uri.host =~ /^\w+[.]apache[.]org$/
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme=='https') do |http|
    http.request Net::HTTP::Get.new uri.request_uri
  end
end

user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user or $USER=='ea'
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

BUILD_TYPES = %w(standard maven ant shell) # forrest
PROJ_PAT = '[a-z][a-z0-9_]+'
URL_PREFIX = 'https://svn.apache.org/repos/asf/'
pmcs = ASF::Committee.list.map(&:mail_list)
export = # TODO: use https://anonymous:@cms.apache.org/export.json
  'https://svn.apache.org/repos/infra/websites/cms/webgui/content/export.json'
WEBSITES = JSON.load(http_get(export).body)

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
          value: @source || URL_PREFIX

        _h3_ 'Project Name'
        _input type: 'text', name: 'project', required: true, value: @project,
          pattern: "^#{PROJ_PAT}$"

        _h3_ 'Site deployment facility'
        _label do
          _input type: "radio", name: "backend", value: "svnpubsub",
            required: true, checked: true
          _a 'svnpubsub', href: 'http://www.apache.org/dev/project-site#intro'
        end
        _label do
          _input type: "radio", name: "backend", value: "cms"
          _a 'Apache CMS', href: 'http://www.apache.org/dev/cmsref'
        end

        _dev.cmsonly do
          _h3_ 'Build Type'
          _select name: 'build_type' do
            BUILD_TYPES.each do |type| 
              _option type, selected: (type == @build_type)
            end
          end
        end

        _h3_ 'Notes'
        _textarea name: 'message', cols: 70, value: @message || ''

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
      error ||= 'Invalid backend' unless %w(cms svnpubsub).include? @backend

       begin
        @source += '/' unless @source.end_with? '/'
        @source.chomp! 'trunk/'
        if not @source.start_with? URL_PREFIX
          error ||= "source URL must be from ASF SVN"
        elsif http_get(URI.parse(@source) + 'trunk/content/').code != '200'
          error ||= "trunk/content directory not found in source URL"
        elsif @pmc=='incubator' 
          if not @source.include? @project.gsub('-','/')
            error ||= "#{@project.gsub('-','/')} not found in source URL"
          end
        end

        if WEBSITES.values.include? @source
          error = "#{@source} is already using the CMS"
        elsif WEBSITES.keys.include? @project
          if @source.include? 'incubator' or not WEBSITES[@project].include? 'incubator' 
            error = "Project name #{@project} is already in use by #{WEBSITES[@project]}"
          end
        end

        required = []
        # TODO: set @build_type=nil for svnpubsub builds
        required << 'trunk/lib/view.pm' if @build_type == 'standard'
        required << 'trunk/build.xml' if @build_type == 'ant'
        required << 'trunk/build_cms.sh' if @build_type == 'shell'
        required << 'trunk/pom.xml' if @build_type == 'maven'
        required << 'pom.xml' if @build_type == 'maven'
        required = ['index.html'] if @backend == 'svnpubsub'

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
          backend: @backend,
        }
        vars[:message] = @message unless @message.empty?
        if @backend == 'cms'
          vars[:build] = @build_type
        end
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

    SRC_PAT = 
      %r{#{URL_PREFIX}(#{PROJ_PAT})/?(#{PROJ_PAT})?/.}

    _script %{
      // when source changes, set project and list
      $('input[name=source]').change(function() {
        if ($(this).val().indexOf('http:') == 0) {
          $(this).val($(this).val().replace('http:', 'https:'));
        }

        var match = #{SRC_PAT.inspect}.exec($(this).val());
        if (match) {
          $('select[name=pmc]').val(match[1]);
          if (match[2]) {
            if (match[1] == 'incubator') {
              $('input[name=project]').val(match[2]);
            } else if (match[2] == 'site') {
              $('input[name=project]').val(match[1]);
            } else {
              $('input[name=project]').val(match[1]+'-'+match[2]);
            }
          } else {
            $('input[name=project]').val(match[1]);
          }
        }
      });

      // Hide the CMS-only fields.
      $('input[name=backend]').change(function() {
        if ($(this).val() != 'cms') {
          $('.cmsonly').hide();
        }
        else {
          $('.cmsonly').show();
        }
      });
      $('.cmsonly').hide();

      // place cursor at end of source url
      $('input[name=source]').focus(function() {
        var value = $(this).val();
        this.setSelectionRange(value.length, value.length);
      }).focus();
    }
  end
end
