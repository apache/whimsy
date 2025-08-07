# Find site image files

module ASF
    # Utility method for listing site images (icons, etc.)
    class SiteImage
        def self.listnames
            _, list = ASF::SVN.getlisting('site-img')
            list
        end

        # See https://www.apache.org/logos/about.html
        # Sort is done by JS using the stem only
        def self.find(id)
            listnames.select{|file| file =~ /^#{id}.*\.(svg|eps|ai|pdf|png)$/}
                .sort_by{|x| File.basename(x, '.*')}.first
        end
    end
end
