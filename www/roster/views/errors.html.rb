#
# Error display
#

_html do
  _header do
    _link rel: 'stylesheet', href: 'stylesheets/app.css'
  end
  _body? do
    _whimsy_header 'Error - Apache Whimsy'
    _whimsy_content do
      _div.row do
        _div.col_sm_10 do
          _div.panel.panel_danger do
            _div.panel_heading {_h3.panel_title 'Error - Apache Whimsy'}
            _div.panel_body do
              _p '"Hey, Rocky! Watch me pull a rabbit out of my hat."'
              _p 'Oh, snap!  Something went wrong.  Error details follow:'
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
