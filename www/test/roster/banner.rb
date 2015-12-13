#
# common banner
#

class Wunderbar::HtmlMarkup
  def _banner(args)
    # logo
    _a href: 'http://whimsy.apache.org/' do
      _img src: 'https://id.apache.org/img/asf_logo_wide.png',
        alt: 'ASF Logo', title: 'ASF Logo'
    end

    # breadcrumbs
    if args[:breadcrumbs]
      _div.breadcrumbs do
        _a href: 'http://www.apache.org' do
          _span.glyphicon.glyphicon_home
        end

        _a 'whimsy', href: 'https://www.whimsy.org/'
        args[:breadcrumbs].each do |name, link|
          _span "\u00BB"
          _a name.to_s, href: link
        end
      end
    end
  end
end
