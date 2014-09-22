require_relative '../asf'

module ASF

  class Site
    @@list = {}

    def self.list
      Committee.load_committee_info
      templates = ASF::SVN['asf/infrastructure/site/trunk/templates']
      file = "#{templates}/blocks/projects.mdtext"
      return @@list if not @@list.empty? and File.mtime(file) == @@mtime
      @@mtime = File.mtime(file)

      projects = File.read(file)
      projects.scan(/\[(.*?)\]\((http.*?) "(.*)"\)/).each do |name, link, text|
        @@list[Committee.find(name).name] = {link: link, text: text}
      end

      @@list
    end
  end

end
