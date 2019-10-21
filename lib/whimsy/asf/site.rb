require 'yaml'

module ASF

  # A list of ASF sites, formed by parsing
  # <tt>private/committers/board/committee-info.yaml</tt> from svn.

  class Site
    @@list = {}
    @@mtime = 0

    # parse the data file
    def self.list
      board = ASF::SVN.find('board')
      file = File.join(board, 'committee-info.yaml')
      if not File.exist?(file)
        Wunderbar.error "Unable to find 'committee-info.yaml'"
        return {}
      end
      return @@list if not @@list.empty? and File.mtime(file) == @@mtime
      yaml = YAML.load_file file
      @@mtime = File.mtime(file)
      @@list = yaml[:cttees].merge yaml[:tlps]
    end

    # find the site for a given committee.
    def self.find(committee)
      committee = committee.name if ASF::Committee == committee
      list[committee]
    end
  end

  class Committee
    # website for this committee.  Data is sourced from ASF::Site.
    def site
      site = ASF::Site.find(name)
      site[:site] if site
    end

    # description for this committee.  Data is sourced from ASF::Site.
    def description
      site = ASF::Site.find(name)
      site[:description] if site
    end
  end
end
