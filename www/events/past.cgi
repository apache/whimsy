#!/usr/bin/env ruby
PAGETITLE = "ApacheCon Historical Listing" # Wvisible:apachecon

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'csv'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

ifields = {
  'SessionList'	=> ['glyphicon-th-list', 'Session Listing'],
  'SlideArchive' => ['glyphicon-file', 'Slide Archives'],
  'VideoArchive' => ['glyphicon-facetime-video', 'Video Archive'],
  'AudioArchive' => ['glyphicon-headphones', 'Audio Archive'],
  'PhotoAlbum' => ['glyphicon-camera', 'Photo Album']
}

_html do
  _body? do
    _whimsy_header PAGETITLE
    ac_dir = ASF::SVN['private/foundation/ApacheCon']
    history = File.read("#{ac_dir}/apacheconhistory.csv")
    history.sub! "\uFEFF", '' # remove Zero Width No-Break Space
    csv = CSV.parse(history, headers:true)
    _whimsy_content do
      _p do
        _ 'ApacheCon is the official conference of the ASF, and the next '
        _a 'ApacheCon is in Miami, May 2017!', href: 'http://events.linuxfoundation.org/events/apachecon-north-america/'
      end 
      _p 'ApacheCon has been going on since before the ASF was born, and includes great events:'
      _ul do
        csv.each do |r|
          _li do
            _a r['Name'], href: r['Link']
            _ ", was held in #{r['Location']}. "
            _br
            ifields.each do |fn, g|
              if r[fn] then
                _a! href: r[fn] do
                  _span!.glyphicon class: "#{g[0]}"
                  _! ' ' + g[1]
                end
              end
            end
          end
        end        
      end
    end
    
    _whimsy_footer({
      "https://www.apache.org/foundation/marks/resources" => "Trademark Site Map",
      "https://www.apache.org/foundation/marks/list/" => "Official Apache Trademark List"
      })
  end
end
