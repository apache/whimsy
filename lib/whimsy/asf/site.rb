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

    # find the data for a given committee.
    def self.find(committee)
      committee = committee.name if committee.is_a? ASF::Committee
      list[committee]
    end

    # append the description for a new tlp committee.
    # this is intended to be called from todos.json.rb in the block for ASF::SVN.update
    def self.appendtlp(input,committee,description)
      output = input # default no change
      yaml = YAML.load input
      if yaml[:cttees][committee]
        Wunderbar.warn "Entry for '#{committee}' already exists under :cttees"
      elsif yaml[:tlps][committee]
        Wunderbar.warn "Entry for '#{committee}' already exists under :tlps"
      else
        data = { # create single entry in :tlps hierarchy
          tlps: {
            committee => {
              site: "http://#{committee}.apache.org",
              description: description,
            }
          }
        }
        # Use YAML dump to ensure correct syntax
        # drop the YAML header
        newtlp = YAML.dump(data).sub(%r{^---\n:tlps:\n}m,'')
        # add the new section just before the ... terminator
        output = input.sub(%r{^\.\.\.},newtlp+"...")
        # Check it worked
        check = YAML.load(output)
        unless data[:tlps][committee] == check[:tlps][committee]
          Wunderbar.warn "Failed to add section for #{committee}"
          output = input # don't change anything
        end
      end
      output
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
