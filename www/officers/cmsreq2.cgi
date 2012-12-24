#!/usr/bin/ruby1.9.1
require 'wunderbar'
require '/var/tools/asf'
require 'shellwords'

# TODO copy-pasted from mlreq.cgi; dedup!
# extract the names of podlings (and aliases) from podlings.xml
require 'nokogiri'
def list_podlings()
  incubator_content = ASF::SVN['asf/incubator/public/trunk/content']
  current = Nokogiri::XML(File.read("#{incubator_content}/podlings.xml")).
    search('podling[status=current]')
  podlings = current.map {|podling| podling['resource']}
  podlings += current.map {|podling| podling['resourceAliases']}.compact.
    map {|names| names.split(/[, ]+/)}.flatten
  podlings.grep Regexp.new "^#{PROJ_PAT}$"
end

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

FORMAT_NUMBER = 1 # json format number
BUILD_TYPES = %w(default maven ant shell) # forrest
PROJ_PAT = '[a-z][a-z0-9_]+'
URL_PREFIX = 'https://svn.apache.org/repos/asf/incubator'
podlings = list_podlings()
export = # TODO: use https://anonymous:@cms.apache.org/export.json
  'https://svn.apache.org/repos/infra/websites/cms/webgui/content/export.json'
WEBSITES = JSON.load(http_get(export).body)
podlings.delete_if {|podling| WEBSITES.keys.include? podling}
# TODO: also delete podlings that have svnpubsub set up

_html do

  _head_ do
    _title 'ASF CMS Request'
    _script src: '/jquery-min.js'
    _style %{
      textarea, .mod, label {display: block}
      input, select[name=build_type] {margin-left: 2em}
      input[name=source]{margin-left: inherit}
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
        _label do
          _ URL_PREFIX
          _ '/'
          _select name: 'project' do
            podlings.sort.each do |podling| 
              _option podling, selected: (podling == @project)
            end
          end
          _ '/'
          _input type: 'url', name: 'source', required: true,
            pattern: "^#{PROJ_PAT}$", value: @source || ''
        end
        _p do
          _em! do
            _ 'Is your podling not listed? See '
            _a 'documentation',
              href: 'http://www.apache.org/dev/infra-contact#requesting-podling'
            _ '.'
          end
        end

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

        _div.cmsonly do
          _h3_ 'CMS Build Type'
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
      error ||= 'Invalid build type' unless BUILD_TYPES.include? @build_type
      error ||= 'Invalid backend' unless %w(cms svnpubsub).include? @backend
      error ||= 'Invalid project' unless /^#{PROJ_PAT}$/.match @project
      error ||= 'Invalid project' unless podlings.include? @project
      error ||= 'Dubious URL' unless @source =~ /^([\/A-Za-z0-9_-]|[.][^.])+$/;

      # TODO: untaint @project here?

      unless error
       begin
        @source = "#{URL_PREFIX}/#{@project}/#{@source}"
        @source += '/' unless @source.end_with? '/'
        @source.chomp! 'trunk/'
        if @backend == 'cms' and http_get(URI.parse(@source) + 'trunk/content/').code != '200'
          error ||= "trunk/content directory not found in source URL"
        end

        # TODO: also catch existing svnwcsub.conf entries
        if WEBSITES.values.include? @source
          # TODO: condition will never match, since @source has trailing slash,
          #       but WEBSITES.values don't.
          error = "#{@source} is already using the CMS"
        elsif WEBSITES.keys.include? @project
          error = "Project name #{@project} is already in use by " \
                  "#{WEBSITES[@project]}"
        end

        required = []
        # TODO: set @build_type=nil for svnpubsub builds
        required << 'trunk/lib/view.pm' if @build_type == 'default'
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
          version: FORMAT_NUMBER,
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

    _script %{
      // force source url to https.
      $('input[name=source]').change(function() {
        if ($(this).val().indexOf('http:') == 0) {
          $(this).val($(this).val().replace('http:', 'https:'));
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
