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
        _div.row do
          _div.col_sm_4.hidden_xs do
            _a href: 'https://www.apache.org/' do
              _img title: 'The Apache Software Foundation', alt: 'ASF Logo', width: 250, height: 101,
                style: "margin-left: 10px; margin-top: 10px;",
                src: 'https://www.apache.org/foundation/press/kit/asf_logo_small.png'
            end
          end
          _div.col_sm_3.col_xs_3 do
            _a href: '/' do
              _img title: 'Whimsy project home', alt: 'Whimsy hat logo', src: 'https://whimsy.apache.org/whimsy.svg', width: 145, height: 101 
            end
          end
          _div.col_sm_5.col_xs_9.align_bottom do 
            _ul class: 'nav nav-tabs' do
              _li role: 'presentation' do
                _a 'Code', href: 'https://github.com/apache/whimsy/'
              end
              _li role: 'presentation' do
                _a 'Questions', href: 'https://lists.apache.org/list.html?dev@whimsical.apache.org'
              end
              _li role: 'presentation' do
                _a 'About', href: '/technology'
              end
              _li role: 'presentation' do
                _span.badge id: 'script-ok'
              end
            end
          end
        end      
        _h1 title
      end
    end
  end
    
  # Wrap content with nicer fluid margins
  def _whimsy_content colstyle="col-lg-11"
    _div.content.container_fluid do
      _div.row do
        _div class: colstyle do
          yield
        end
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