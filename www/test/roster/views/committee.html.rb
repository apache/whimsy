#
# A single committee
#

_html do
  _base href: '..'
  _title @committee[:display_name]
  _link rel: 'stylesheet', href: '../stylesheets/app.css'

  _a href: 'http://whimsy.apache.org/' do
    _img src: 'https://id.apache.org/img/asf_logo_wide.png',
      alt: 'ASF Logo', title: 'ASF Logo'
  end

  _div_.main!

  _script src: '../app.js'
  _.render '#main' do
    _Committee committee: @committee
  end
end
