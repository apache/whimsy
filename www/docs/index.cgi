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

PAGETITLE = "Apache Whimsy Code Documentation" # Wvisible:docs

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

_html do
  _body? do
    _whimsy_body(
      title: PAGETITLE,
      subtitle: 'About Whimsy Documentation',
      relatedtitle: 'More Useful Links',
      related: {
        "/committers/tools" => "Listing of All Whimsy Tools",
        "https://github.com/rubys/wunderbar/" => "Wunderbar Module Documentation",
        "https://github.com/apache/whimsy/blob/master/www#{ENV['SCRIPT_NAME']}" => "See This Source Code"
      },
      helpblock: -> {
        _p do
          _ 'This is the homepage for the code and API documentation for the Apache Whimsy project. '
          _a 'Read the mailing list', href: 'https://lists.apache.org/list.html?dev@whimsical.apache.org'
          _ ' or '
          _a 'submit a bug on Whimsy.', href: 'https://lists.apache.org/list.html?dev@whimsical.apache.org'
        end
      }
    ) do
      dev = {
        'https://github.com/apache/whimsy/blob/master/DEVELOPMENT.md' => "Developer Overview / How-To",
        'https://github.com/apache/whimsy/blob/master/CONFIGURE.md' => "How To Configure Whimsy",
        'https://github.com/apache/whimsy/blob/master/DEPLOYMENT.md' => "Deploying Whimsy On Server",
        'https://github.com/apache/whimsy/blob/master/MACOSX.md' => "Mac OSX Local Setup",
        'https://github.com/apache/whimsy/blob/master/README.md' => "Whimsy Intro README",
        '/docs/api/' => "whimsy/asf and ASF:: module API docs",
        "https://github.com/rubys/wunderbar/" => "Wunderbar Module Docs"
      }
      _h2 "Developer Documentation"
      _ul do
        dev.each do |url, desc|
          _li do
            _a desc, href: url
          end
        end
      end
    end
  end
end
