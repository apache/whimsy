#!/usr/bin/env ruby
##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

PAGETITLE = "ApacheCon Historical Listing" # Wvisible:events,apachecon

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'csv'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

ifields = {
  'SessionList' => ['glyphicon-th-list', 'Session Listing'],
  'SlideArchive' => ['glyphicon-file', 'Slide Archives'],
  'VideoArchive' => ['glyphicon-facetime-video', 'Video Archive'],
  'AudioArchive' => ['glyphicon-headphones', 'Audio Archive'],
  'PhotoAlbum' => ['glyphicon-camera', 'Photo Album']
}

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      related: {
        "https://community.apache.org/calendars/" => "Upcoming Apache-related Event Calendar",
        "https://www.apache.org/events/meetups.html" => "Upcoming Apache-related Meetups",
        "/events/other" => "Some non-Apache related event listings"
      },
      helpblock: -> {
        _p do
          _ 'ApacheCon is the official conference of the ASF, and the last '
          _a 'ApacheCon was in Miami, May 2017!', href: 'http://events.linuxfoundation.org/events/apachecon-north-america/'
        end 
        _p 'ApacheCon has been going on since before the ASF was born, and includes great events:'
      }
    ) do
      ac_dir = ASF::SVN['apachecon']
      history = File.read("#{ac_dir}/apacheconhistory.csv")
      history.sub! "\uFEFF", '' # remove Zero Width No-Break Space
      csv = CSV.parse(history, headers:true)
      _ul do
        csv.each do |r|
          _li do
            _a r['Name'], href: r['Link']
            _ ", was held in #{r['Location']}. "
            _ul do
              ifields.each do |fn, g|
                if r[fn] then
                  _li do
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
      end
    end
  end
end
