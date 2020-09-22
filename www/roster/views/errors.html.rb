#
# Error display
#

_html do
  _header do
    _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  end
  _body? do
    _whimsy_body(
      title: '500 Internal Server Error - Apache Whimsy',
      breadcrumbs: {
        roster: '.',
      }
    ) do
      _div.row do
        _div.col_sm_10 do
          _div.panel.panel_danger do
            _div.panel_heading {_h3.panel_title '500 - Internal Server Error'}
            _div.panel_body do
              _p '"Hey, Rocky! Watch me pull a rabbit out of my hat."'
              _p 'Oh, snap!  Something went wrong.  Error details follow:'
              _ul do
                %w( sinatra.error sinatra.route REQUEST_URI ).each do |k|
                  _li "#{k} = #{@errors[k]}"
                end
              end
              _p do
                _ 'ASF Members may also review access protected: '
                _a '/members/log/', href: '/members/log/'
              end
              _p do
                _ 'Also please check for ASF system errors at: '
                _a 'status.apache.org', href: 'http://status.apache.org/'
              end
            end
          end
        end
      end
    end
  end
end
