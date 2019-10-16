#
# Determine status of podling name
#

class PodlingNameSearch < Vue
  def render
    results = nil
    name = @@item.title[/Establish (.*)/, 1]

    # if full title contains a name in parenthesis, check for that name too
    altname = @@item.fulltitle[/\((.*?)\)/, 1]

    if name and Server.podlingnamesearch
      Server.podlingnamesearch.each_pair do |podling, jira|
        results = jira if name == podling or altname == podling
      end
    end

    _span.pns title: 'podling name search' do
      if Server.podlingnamesearch
        if not results
          _a "\u2718", title: 'No PODLINGNAMESEARCH found',
            href: 'https://issues.apache.org/jira/secure/CreateIssue!default.jspa'
        elsif results.resolution == 'Fixed'
          _a "\u2714", href: 'https://issues.apache.org/jira/browse/' +
            results.issue
        else
          _a "\uFE56", href: 'https://issues.apache.org/jira/browse/' +
            results.issue
        end
      end
    end
  end

  # initial mount: fetch podlingnamesearch data unless already downloaded
  def mounted()
    if not Server.podlingnamesearch
      retrieve 'podlingnamesearch', :json do |results|
        Server.podlingnamesearch = results
        Vue.forceUpdate()
      end
    end
  end
end
