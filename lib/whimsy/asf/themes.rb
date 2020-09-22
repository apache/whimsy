require 'wunderbar'

# Define common page features for whimsy tools using bootstrap styles
class Wunderbar::HtmlMarkup

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

  # Emit simplistic copyright footer
  def _whimsy_foot
    _div.footer.container_fluid style: 'background-color: #f5f5f5; padding: 10px;' do
      _p.center do
        # &copy; and &reg; don't work here for cgi scripts - see WHIMSY-146
        _{"Copyright \u00A9 #{Date.today.year}, the Apache Software Foundation. Licensed under the "}
        _a 'Apache License, Version 2.0', rel: 'license', href: 'http://www.apache.org/licenses/LICENSE-2.0'
        _ ' | '
        _a 'Privacy Policy', href: 'https://www.apache.org/foundation/policies/privacy'
        _br
        _{"Apache\u00AE, the names of Apache projects, and the multicolor feather logo are "}
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
  def _whimsy_body(title: nil,
      subtitle: 'About This Script',
      relatedtitle: 'Related Whimsy Links',
      related: nil,
      helpblock: nil,
      breadcrumbs: nil,
      style: 'panel-info'
    )
    _whimsy_nav
    _div.content.container_fluid do
      _div.row do
        _div.col_sm_12 do
          _h1 title if title
        end
      end
      if helpblock or related
        _div.row do
          _div.col_md_8 do
            _whimsy_panel subtitle, style: style do
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

  # Emit wrapper panels for a single tablist accordion item
  # @param listid of the parent _div.panel_group role: "tablist"
  # @param itemid of this specific item
  # @param itemtitle to display in the header panel
  # @param n unique number of this item (for nav links)
  # @param itemclass optional panel-success or similar styling
  def _whimsy_accordion_item(listid: 'accordion', itemid: nil, itemtitle: '', n: 0, itemclass: nil)
    raise ArgumentError.new("itemid must not be nil") if not itemid
    args = {id: itemid}
    args[:class] = itemclass if itemclass
    _div!.panel.panel_default args do
      _div!.panel_heading role: "tab", id: "#{listid}h#{n}" do
        _h4!.panel_title do
          _a!.collapsed role: "button", data_toggle: "collapse",  aria_expanded: "false", data_parent: "##{listid}", href: "##{listid}c#{n}", aria_controls: "#{listid}c#{n}" do
            _ "#{itemtitle} "
            _span.glyphicon.glyphicon_chevron_down id: "#{itemid}-nav"
          end
        end
      end
      _div!.panel_collapse.collapse id: "#{listid}c#{n}", role: "tabpanel", aria_labelledby: "#{listid}h#{n}" do
        _div!.panel_body do
          yield
        end
      end
    end
  end

end
