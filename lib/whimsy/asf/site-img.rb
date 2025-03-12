# Find site image files

module ASF
    # Utility method for listing site images (icons, etc.)
    class SiteImage
        def self.listnames
            _, list = ASF::SVN.getlisting('site-img')
            list
        end

        def self.find(id)
            listnames.select{|file| file =~ /^#{id}.*\.(svg|eps|ai|pdf)$/}.first
        end
    end
end
