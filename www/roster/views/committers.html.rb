#
# Search Committer list
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  if @notinavail
    breadcrumbs = {
      roster: '.',
      committer2: 'committer2/'
    }
  else
    breadcrumbs = {
      roster: '.',
      committer: 'committer/'
    }
  end
  _whimsy_body(
    title: 'ASF Committer Search',
    breadcrumbs: breadcrumbs
  ) do
    _div_.main!
    _script src: "app.js?#{appmtime}"
    _.render '#main', timeout: 1 do
      _CommitterSearch notinavail: @notinavail,
                       # This ends with '/'
                       iclapath: @iclapath
    end
  end
end
