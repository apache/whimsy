#!/usr/bin/env ruby

print "Status: 301 Moved Permanently\r\n"
print "Location: ../events/past\r\n"
print "\r\n"
exit

$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'csv'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

PAGETITLE = 'ApacheCon Historical Listing - DEPRECATED'
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
    history = File.read("#{ac_dir}/apacheconhistory.csv")
    history.sub! "\uFEFF", '' # remove Zero Width No-Break Space
    csv = CSV.parse(history, headers:true)
    _whimsy_content do
      _p do 
        _ 'THIS PAGE IS DEPRECATED - please see '
        _a '/events/past', href: 'https://whimsy.apache.org/events/past'
        _ 'instead. Past ApacheCons include:'
      end
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
