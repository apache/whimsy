require 'wunderbar'

# Define common page features for whimsy tools using bootstrap styles
class Wunderbar::HtmlMarkup
  # Emit ASF style header with _h1 title and common links
  def _whimsy_header title, style = :full
    case style
    when :mini
      _div.header do
        _h1 title
      end
    else
      _div.header.container_fluid do
        _ul class: 'nav nav-tabs' do
          _li role: 'presentation' do
            _a href: 'https://www.apache.org/' do
              _img title: 'ASF Logo', alt: 'ASF Logo', width: 250, height: 101,
                src: 'https://www.apache.org/foundation/press/kit/asf_logo_small.png'
            end
          end
          _li role: 'presentation' do
            _a href: '/' do
              _img title: 'Whimsy logo', alt: 'Whimsy hat', src: 'https://whimsy.apache.org/whimsy.svg', height: 101 
            end
          end
          _li role: 'presentation' do
            _a 'Mailing list', href: 'https://lists.apache.org/list.html?dev@whimsical.apache.org'
          end
          _li role: 'presentation' do
            _a 'About this site', href: '/technology'
          end
          _li role: 'presentation' do
            _span.badge id: 'script-ok'
          end
        end
        _h1 title
      end
    end
  end
  
  # Emit ASF style footer with (optional) list of related links
  def _whimsy_footer related
    _div.footer.container_fluid do
      _div.panel.panel_default do 
        _div.panel_heading do
          _h3.panel_title 'Related Apache Resources'
        end
        _div.panel_body do
          _ul do
            related.each do |url, desc|
              _li do
                _a desc, href: url
              end
            end
          end
        end
      end
    end
  end
end