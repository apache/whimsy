require 'wunderbar'

# Define common page features for whimsy tools using bootstrap styles
class Wunderbar::HtmlMarkup
  # DEPRECATED Emit ASF style header with _h1 title and common links
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
              _img title: 'Whimsy project home', alt: 'Whimsy hat logo', src: '/whimsy.svg', width: 145, height: 101 
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
    
  # DEPRECATED Wrap content with nicer fluid margins
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
  def _whimsy_footer **args
    _div.footer.container_fluid do
      _div.panel.panel_default do 
        _div.panel_heading do
          _h3.panel_title 'Related Apache Resources'
        end
        _div.panel_body do
          _ul do
            if args.key?(:related)
              args[:related].each do |url, desc|
                _li do
                  _a desc, href: url
                end
              end
            else
              _li do
                _a 'Whimsy Source Code', href: 'https://github.com/apache/whimsy/'
              end
            end
          end
        end
      end
    end
  end
  
  # Emit simplistic copyright footer
  def _whimsy_foot
    _div.footer.container_fluid style: 'background-color: #f5f5f5; padding: 10px;' do
      _p.center do
        _{'Copyright &copy; 2017, the Apache Software Foundation. Licensed under the '}
        _a 'Apache License, Version 2.0', rel: 'license', href: 'http://www.apache.org/licenses/LICENSE-2.0'
        _ ' | '
        _a 'Privacy Policy', href: 'https://www.apache.org/foundation/policies/privacy'
        _br
        _{'Apache&reg;, the names of Apache projects, and the multicolor feather logo are '}
        _a 'registered trademarks or trademarks', href: 'https://www.apache.org/foundation/marks/list/'
        _ ' of the Apache Software Foundation in the United States and/or other countries.'
      end
    end
  end
  
  # Emit a panel with title and body content
  def _whimsy_panel(title, style: 'panel-primary', header: 'h3')
    _div.panel class: style do
      _div.panel_heading do 
        _.tag! header, class: 'panel-title' do
          _ title
        end
      end
      _div.panel_body do
        yield
      end
    end
  end
  
  # Emit a panel with helpblock and table https://getbootstrap.com/components/#panels-tables
  def _whimsy_panel_table(title: 'Table Title', style: 'panel-primary', header: 'h2', helpblock: nil)
    _div.panel class: style do
      _div.panel_heading do 
        _.tag! header, class: 'panel-title' do
          _ title
        end
      end
      if helpblock
        _div.panel_body do
          helpblock.call
        end
      end
      yield
    end
  end
  
  # Emit a bootstrap navbar with required ASF links
  def _whimsy_nav
    _nav.navbar.navbar_default do
      _div.container_fluid do
        _div.navbar_header do
          _button.navbar_toggle.collapsed type: "button", data_toggle: "collapse", data_target: "#navbar_collapse", aria_expanded: "false" do
            _span.sr_only "Toggle navigation"
            _span.icon_bar
            _span.icon_bar
          end
          _a.navbar_brand href: '/' do
            _img title: 'Whimsy project home', alt: 'Whimsy hat logo', src: '/whimsy.svg', height: 30
          end
        end
        _div.collapse.navbar_collapse id: "navbar_collapse" do
          _ul.nav.navbar_nav do
            _li do
              _a 'Code', href: 'https://github.com/apache/whimsy/'
            end
            _li do
              _a 'Questions', href: 'https://lists.apache.org/list.html?dev@whimsical.apache.org'
            end
            _li do
              _a 'About Whimsy', href: '/technology'
            end
          end
          _ul.nav.navbar_nav.navbar_right do
            _li.dropdown do
              _a.dropdown_toggle href: "#", data_toggle: "dropdown", role: "button", aria_haspopup: "true", aria_expanded: "false" do
                _img title: 'Apache Home', alt: 'Apache feather logo', src: 'https://www.apache.org/img/feather_glyph_notm.png', height: 30
                _ ' Apache'
                _span.caret
              end
              _ul.dropdown_menu do
                _li do
                  _a 'License', href: 'http://www.apache.org/licenses/'
                end
                _li do
                  _a 'Donate', href: 'http://www.apache.org/foundation/sponsorship.html'
                end
                _li do
                  _a 'Thanks', href: 'http://www.apache.org/foundation/thanks.html'
                end
                _li do
                  _a 'Security', href: 'http://www.apache.org/security/'
                end
                _li.divider role: 'separator'
                _li do
                  _a 'About The ASF', href: 'http://www.apache.org/'
                end
              end
            end
          end
        end
      end
    end
  end

  # Emit complete bootstrap theme to wrap cgi output, including nav and footer
  # If helpblock or related, then emit helpblock and related* panels before content
  # If breadcrumbs, emit those immediately before content
  def _whimsy_body(title: 'MOAR WHIMSY!', 
      subtitle: 'About This Script', 
      relatedtitle: 'Related Whimsy Links', 
      related: nil, 
      helpblock: nil,
      breadcrumbs: nil
    )
    _whimsy_nav
    _div.content.container_fluid do
      _div.row do
        _div.col_sm_12 do
          _h1 title
        end
      end
      if helpblock or related
        _div.row do
          _div.col_md_8 do
            _whimsy_panel subtitle, style: "panel-info" do
              if helpblock
                helpblock.call
              else
                _a 'See this code', href: "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}"
              end
            end
          end
          _div.col_md_4 do
            _whimsy_panel relatedtitle, style: "panel-default" do
              _ul list_style_position: 'inside' do
                if related
                  related.each do |url, desc|
                    if url =~ /.*\.(png|jpg|svg|gif)\z/i
                      # Extension: allow images, style to align with bullets
                      _li.list_unstyled do
                        _img alt: desc, src: url, height: '60px', style: 'margin-left: -20px; padding: 2px 0px;'
                      end
                    else
                      _li do
                        _a desc, href: url
                      end
                    end
                  end
                else
                  _li do
                    _a 'See this code', href: "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}"
                  end
                end
              end
            end
          end
        end
      end
      _div.row do
        _div.col_sm_12 do
          if breadcrumbs
            _ol.breadcrumb do
              _li do
                _a href: '/' do
                  _span.glyphicon.glyphicon_home
                end
              end
              breadcrumbs.each do |name, link|
                _li.active do
                  _a name.to_s, href: link
                end
              end
            end
          end
          # Primary content from caller emitted below
          yield
        end
      end
      _whimsy_foot
    end    
  end
end