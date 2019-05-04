##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

require_relative '../asf'
require 'nokogiri'

module ASF

  # A list of ASF sites, formed by parsing
  # <tt>asf/infrastructure/site/trunk/content</tt> from svn.

  class Site
    # add entries that are not currently defined in index.html (or elsewhere)
    @@default = {
      "brandmanagement" => {
        link: "http://www.apache.org/foundation/marks/pmcs",
        text: "define how Apache projects should refer to trademarks and display their brand"
      },
      "comdev" => {
        link: "http://community.apache.org/",
        text: "Resources to help people become involved with Apache projects"
      },
      "executiveassistant" => {
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
      "legalaffairs" => {
        link: "http://www.apache.org/legal/",
        text: "Establishing and managing legal policies"
      },
      "marketingandpublicity" => {
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
      "w3crelations" => {
        link: "http://www.apache.org/foundation/foundation-projects.html#w3c",
        text: "Liaison between the ASF and the World Wide Web Consortium"
      },
    }
    @@list = {}

    # a Hash of all sites.  Keys are the committee names.  Values are a hash
    # with <tt>:link</tt>, and <tt>:text<tt> values.
    def self.list
      templates = ASF::SVN['site-root']
      file = File.join(templates, 'index.html')
      if not File.exist?(file)
        Wunderbar.error "Unable to find 'infrastructure/site/trunk/content/index.html'"
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

    # find the site for a give committee.
    def self.find(committee)
      committee = committee.name if ASF::Committee == committee
      list[committee]
    end
  end


  class Committee
    # website for this committee.  Data is sourced from ASF::Site.
    def site
      site = ASF::Site.find(name)
      site[:link] if site
    end

    # description for this committee.  Data is sourced from ASF::Site.
    def description
      site = ASF::Site.find(name)
      site[:text] if site
    end
  end
end
