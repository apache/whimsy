#!/usr/bin/ruby1.9.1
require 'wunderbar'
require '/var/tools/asf'

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
    _style %{
      textarea, .mod, label {display: block}
      input[type=submit] {display: block; margin-top: 1em}
      legend {background: #141; color: #DFD; padding: 0.4em}
      input[type=text] {width: 6em}
      input[type=url] {width: 30em}
    }
  end

  _body? do
    _form method: 'post' do
      _fieldset do
        _legend 'ASF CMS Request'

        _h3_ 'CMS Name'
        _input type: 'text', name: 'cms', required: true, pattern: '^\w+$',
          value: @cms

        _h3_ 'Source URL'
        _input type: 'url', name: 'source', required: true,
          value: @source || 'https://svn.apache.org/repos/asf/'

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
      error ||= 'Invalid CMS name'  unless @cms =~ /^\w+$/
      error ||= 'Invalid build type' unless BUILD_TYPES.include? @build_type

      unless ASF::Mail.lists.include? "#{@pmc}-#{@list}"
        error ||= "Mail list doesn't exist"
      end

      begin
        @source += '/' unless @source.end_with? '/'
        if http_get(URI.parse(@source.untaint) + 'trunk/content/').code != '200'
          error ||= "content directory not found in source URL"
        end
      rescue Exception => exception
        error = "Exception processing URL: #{exception}"
      end

      if error
        _h2_ 'Error'
        _p error
      else
        _h2_ 'Request would be accepted if this application were complete'
      end
    end
  end
end

require 'net/http'
def http_get(uri)
  uri = URI.parse(uri) if String === uri
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme=='https') do |http|
    http.request Net::HTTP::Get.new uri.request_uri
  end
end

