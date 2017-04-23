#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'csv'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

PAGETITLE = 'ApacheCon Historical Listing'
ifields = {
  'SessionList'	=> 'glyphicon_th_list',
  'SlideArchive' => 'glyphicon_file',
  'VideoArchive' => 'glyphicon_facetime_video',
  'AudioArchive' => 'glyphicon_headphones',
  'PhotoAlbum' => 'glyphicon_camera'
}

_html do
  _body? do
    _whimsy_header PAGETITLE
    ac_dir = ASF::SVN['private/foundation/ApacheCon']
    csv = CSV.read("#{ac_dir}/apacheconhistory.csv", headers:true)
    _whimsy_content do
      _p 'Past ApacheCons include:'
      _ul do
        csv.each do |r|
          _li do
            _span.text_primary do
              _a r['Name'], href: r['Link']
            end
            _ ", held in #{r['Location']}. "
            _br
            ifields.each do |fn, g|
              if r[fn] then
                _a! href: r[fn] do
                  _span!.glyphicon class: "#{g}"
                  _! ' ' + fn
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
