#
# Fetch and maintain a local cache of reporter.apache.org "forgotten" drafts.
# Select projects with drafts for the current agenda and sort by attachment.
#
# Note: reporter will return partial results for non-members.  Once full
# results are retrieved, serve from the cache for the next minute.
#

class Reporter
  @@partial = true
  @@agenda = nil
  @@digest = nil

  def self.drafts(env, update=nil)
    changed = false

    agenda_file = File.basename(Dir["#{FOUNDATION_BOARD}/board_agenda_*.txt"].max)

    if ENV['RACK_ENV'] == 'test'
      return {agenda: agenda_file, drafts: []}
    end

    cache = File.join(ASF::Config.get(:cache), 'reporter-drafts.json')

    # read and prune previous status.  May be used to "fill in the blanks"
    # should a partial set of reports be received
    report_status = (JSON.parse(File.read(cache)) rescue {}).
      select {|project, status| status['agenda'] == agenda_file}.to_h

    # file updates as they are received
    if update

      report_status.merge! update
      File.write cache, report_status.to_json
      changed = true

    # if cache is older than a minute, fetch new data
    elsif not File.exist? cache or File.mtime(cache) < Time.now-60 or @@partial
      # source of truth
      uri = URI.parse('https://reporter.apache.org/api/drafts/forgotten')

      # fetch and merge in latest report statuses
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new(uri)
        request.basic_auth env.user, env.password
        response = http.request(request)
        if response.code == "200"
          report_status.merge! JSON.parse(response.body)['report_status']
        else
          Wunderbar.error "Failed to fetch #{uri}: #{response.code}"
        end

        if not File.exist? cache or JSON.parse(File.read cache) != report_status
          changed = true
        end

        File.write cache, report_status.to_json

        @@partial = (not ASF::Person.find(env.user).asf_member?)
      end
    end

    # extract projects with drafts for this agenda
    lastMeeting = ASF::Board.lastMeeting.to_i
    drafts = report_status.select do |project, status|
      next false unless status['agenda'] == agenda_file
      last_draft = status['last_draft']
      next false if last_draft and status['draft_timestamp'] <= lastMeeting
      last_draft and not last_draft.empty?
    end

    # return agenda and drafts indexed by attachment
    results = {
      agenda: agenda_file,
      drafts: drafts.map {|project, status|
        committee = ASF::Committee.find(project)
        [status['attach'], {
          project: project,
          title: (committee ? committee.display_name : project),
          timestamp: status['draft_timestamp'],
          author: status['last_author'],
          text: status['last_draft']
        }]
      }.to_h
    }

    if changed
      digest = Digest::MD5.hexdigest(JSON.dump(results[:drafts]))
      Events.post type: 'reporter', agenda: agenda_file, digest: digest
    end

    # filter drafts based on user visibility
    user = env.respond_to?(:user) && ASF::Person.find(env.user)
    unless !user or user.asf_member? or ASF.pmc_chairs.include? user
      projects = user.committees.map(&:name)
      results[:drafts].keep_if do |attach, draft|
        projects.include? draft[:project]
      end
    end

    @@digest = Digest::MD5.hexdigest(JSON.dump(results[:drafts]))
    @@agenda = agenda_file
    results[:digest] = @@digest

    results
  end

  # return digest information
  def self.digest
    {agenda: @@agenda, digest: @@digest}
  end
end
