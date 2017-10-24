class Attic
  def self.issues
    @issues = nil if @mtime and Time.now - @mtime > 300

    unless @issues
      require 'cgi'
      query = 'project = ATTIC AND status in (Open, "In Progress", Reopened)'

      uri = URI.parse('https://issues.apache.org/jira/rest/api/2/search?jql=')

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new(uri.request_uri + CGI.escape(query))

        response = http.request(request)

        @issues = JSON.parse(response.body)['issues'].map do |issue|
          [ issue['key'], issue['fields']['summary'] ]
        end
      end
      @mtime = Time.now
    end

    Hash[@issues]
  end
end
