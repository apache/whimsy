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
  def _whimsy_footer **args
    _div.footer.container_fluid do
      _div.panel.panel_default do 
        _div.panel_heading do
          _h3.panel_title 'Related Apache Resources'
        end
        _div.panel_body do
          _ul do
            if args.key?('related')
              args['related'].each do |url, desc|
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
  
  # Emit a panel with title and body content
  def _whimsy_panel(title, style: 'panel-default', header: 'h3')
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
    
  def _whimsy_nav **args
    _nav.navbar.navbar_default do
      _div.container_fluid do
        _div.navbar_header do       
          _button.navbar_toggle.collapsed type: "button", data_toggle: "collapse", data_target: "#bs_example_navbar_collapse_1", aria_expanded: "false" do
            _span.sr_only "Toggle navigation"
            _span.icon_bar
            _span.icon_bar
          end
          _a.navbar_brand href: '/' do
            _img title: 'Whimsy project home', alt: 'Whimsy hat logo', src: 'https://whimsy.apache.org/whimsy.svg', height: 30
          end
        end
        _div.collapse.navbar_collapse id: "bs_example_navbar_collapse_1" do
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
                _ 'Apache'
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
  
  # Emit complete bootstrap theme (container/row/column) for common use cases
  def _whimsy_body **args
    puts JSON.pretty_generate(args)
    _whimsy_nav args
    _div.content.container_fluid do
      _div.row do
        _div.col_sm_12 do
          _h1 args['title']
        end
      end
      _div.row do
        _div.col_sm_12 do
          yield
        end
      end
      _whimsy_footer args
    end
  end

end