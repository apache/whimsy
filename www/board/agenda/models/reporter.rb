class Reporter
  def self.drafts(env)
    agenda_file = File.basename(
      Dir["#{FOUNDATION_BOARD}/board_agenda_*.txt"].sort.last).untaint
    agenda = Agenda.parse(agenda_file, :quick)

    cache = File.join(ASF::Config.get(:cache), 'reporter-drafts.json')

    # if cache is older than a minute, fetch new data
    if not File.exist? cache or File.mtime(cache) < Time.now - 60
      # read and prune previous status.  May be used to "fill in the blanks"
      # should a partial set of reports be received
      report_status = (JSON.parse(File.read(cache)) rescue {}).
        select {|project, status| status['agenda'] == agenda_file}.to_h

      # source of truth
      uri = URI.parse('https://reporter.apache.org/api/drafts/forgotten')

      # fetch and merge in latest report statuses
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new(uri)
        request.basic_auth env.user, env.password
        response = http.request(request)
        report_status.merge! JSON.parse(response.body)['report_status']
        File.write cache, report_status.to_json
      end
    end

    # extract projects with drafts for this agenda
    drafts = JSON.parse(File.read(cache)).select do |project, status| 
      next false unless status['agenda'] == agenda_file
      last_draft = status['last_draft']
      last_draft and not last_draft.empty?
    end

    # return agenda and drafts indexed by attachment
    {
      agenda: agenda_file,
      drafts: drafts.map {|project, status|
        [status['attach'], {
          project: project, 
          timestamp: status['draft_timestamp'],
          author: status['last_author'],
          text: status['last_draft']
        }]
      }.to_h
    }
  end
end
