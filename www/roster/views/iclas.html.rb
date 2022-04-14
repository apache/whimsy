#
# A single committer
#

_html do
  _base href: '..'
  _link rel: 'stylesheet', href: "stylesheets/app.css?#{cssmtime}"
  _whimsy_body(
    title: 'Search pending ASF ICLAs',
    breadcrumbs: {
      roster: '.',
      icla: 'icla/'
    }
  ) do
    _div_.main!
    _script src: "app.js?#{appmtime}"
    _.render '#main', timeout: 1 do
      _IclaSearch iclapath: @iclapath
    end
  end
end
