#
# Error display
#

_html do
  _header do
    _link rel: 'stylesheet', href: 'stylesheets/app.css'
  end
  _body? do
    _whimsy_header '404 Error - Apache Whimsy'
    _whimsy_content do
      _div.row do
        _div.col_sm_10 do
          _div.panel.panel_danger do
            _div.panel_heading {_h3.panel_title '404 - Not Found - Apache Whimsy'}
            _div.panel_body do
              _ %{ Whatever you're looking for is not there.  
                We'll double-check our crystal balls, but you should 
                probably try another 
              }
              _a 'magic link.', href: 'https://whimsy.apache.org/roster/'
              _ul do
                %w( sinatra.error sinatra.route REQUEST_URI ).each do |k|
                  _li "#{k} = #{@errors[k]}"
                end
              end
            end
          end
        end
      end
    end
  end
end
