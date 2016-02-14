require_relative '../asf'
require 'nokogiri'

module ASF

  class Site
    # add entries that are not currently defined in index.html (or elsewhere)
    @@default = {
      "brand management" => {
        link: "http://www.apache.org/foundation/marks/pmcs",
        text: "define how Apache projects should refer to trademarks and display their brand"
      },
      "comdev" => {
        link: "http://community.apache.org/",
        text: "Resources to help people become involved with Apache projects"
      },
      "executive assistant" => {
        link: "http://www.apache.org/foundation/ASF-EA.html",
        text: "Executive Assistant"
      },
      "fundraising" => {
        link: "http://www.apache.org/foundation/contributing.html",
        text: "Fund Raising"
      },
      "infrastructure" => {
        link: "http://www.apache.org/dev/infrastructure.html",
        text: "Infrastructure Team"
      },
      "legal affairs" => {
        link: "http://www.apache.org/legal/",
        text: "Establishing and managing legal policies"
      },
      "marketing and publicity" => {
        link: "http://www.apache.org/press/",
        text: "public relations and for the press-related issues"
      },
      "security" => {
        link: "http://www.apache.org/security/",
        text: "Security Team"
      },
      "tac" => {
        link: "http://www.apache.org/travel/",
        text: "Travel Assistance Committee"
      },
      "w3c relations" => {
        link: "http://www.apache.org/foundation/foundation-projects.html#w3c",
        text: "Liaison between the ASF and the World Wide Web Consortium"
      },
    }
    @@list = {}

    def self.list
      templates = ASF::SVN['asf/infrastructure/site/trunk/content']
      file = "#{templates}/index.html"
      if not File.exist?(file)
        Wunderbar.warn "Unable to find 'infrastructure/site/trunk/content'"
        return {}
      end
      return @@list if not @@list.empty? and File.mtime(file) == @@mtime
      @@mtime = File.mtime(file)

      @@list = @@default

      Committee.load_committee_info
      doc = Nokogiri::HTML.parse(File.read(file))
      list = doc.at("#by_name")
      if list
        list.search('a').each do |a|
          @@list[Committee.find(a.text).name] = 
            {link: a['href'], text: a['title']}
        end
      end

      list = doc.at("#by_category")
      if list
        list.search('a').each do |a|
          if a['title']
            @@list[Committee.find(a.text).name] = 
              {link: a['href'], text: a['title']}
          end
        end
      end

      @@list
    end

    def self.find(committee)
      committee = committee.name if ASF::Committee == committee
      list[committee]
    end
  end


  class Committee
    def site
      site = ASF::Site.find(name)
      site[:link] if site
    end

    def description
      site = ASF::Site.find(name)
      site[:text] if site
    end
  end
end
