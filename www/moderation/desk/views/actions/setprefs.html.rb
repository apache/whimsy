# Set user preferences

require_relative '../../defines'

params = @request.params
prefs = []
if @info[:member] && params[ALLDOMAINS] == 'on'
  prefs << ALLDOMAINS
end

# We keep the other settings to make it easier to switch back
@info[:project_owners].each do |p|
  p += '.apache.org' # TODO improve this
  if params[p] == 'on'
    prefs << p
  end
end

_html do
  _title 'ASF Moderation Helper - setting preferences'
  _link rel: 'stylesheet', type: 'text/css', href: "../secmail.css?#{@cssmtime}"
  _header_ do
    _h1.bg_success do
      _a 'ASF Moderation Helper', href: '..', target: '_top'
      _ ' - setting preferences'
    end
  end
  @prefs[@id]=prefs
  _p "Successfully updated the project list for #{@id}"
  _p do
    _ 'Return to '
    _a 'ASF Moderation Helper', href: '..', target: '_top'
  end
end
