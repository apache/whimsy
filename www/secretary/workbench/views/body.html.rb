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

#
# View the email content, without attachments
#

_html do
  _link rel: 'stylesheet', type: 'text/css', 
    href: "../../secmail.css?#{@cssmtime}"

  #
  # Selected headers
  #
  _table do
    _tr do
      _td 'From:'
      _td @message.from
    end

    _tr do
      _td 'To:'
      _td @message.to
    end

    if @message.cc and not @message.cc.empty?
      _tr do
        _td 'Cc:'
        _td @message.cc.join(', ')
      end
    end

    _tr do
      _td 'Subject:'
      _td @message.subject || '(empty)'
    end
  end

  _p

  #
  # Try various ways to display the body
  #
  if @message.html_part
    _div do
      body = @message.html_part.body.to_s

      if body.to_s.encoding == Encoding::BINARY and @message.html_part.charset
        body.force_encoding(@message.html_part.charset) rescue nil
      end

      nodes = _{body.encode('utf-8', invalid: :replace, undef: :replace)}

      fixup_images(nodes)
    end
  elsif @message.text_part
    body = @message.text_part.body.to_s

    if body.to_s.encoding == Encoding::BINARY and @message.text_part.charset
      body.force_encoding(@message.text_part.charset) rescue nil
    end

    _pre.bg_info body.encode('utf-8', invalid: :replace, undef: :replace)
  else # must be a non-multipart message
    body_part = @message.mail.body
    body = body_part.to_s
    mime_type = @message.mail.mime_type
    charset = @message.mail.charset # N.B. not @message.mail.body.charset

    _.comment! "body.encoding=#{body.encoding} charset=#{charset} mime_type=#{mime_type}"

    if body.encoding == Encoding::BINARY and charset
      body.force_encoding(charset) rescue nil
    end

    if mime_type == 'text/plain'
      _pre.bg_info body.encode('utf-8', invalid: :replace, undef: :replace)
    elsif mime_type == 'text/html'
      _div do
        nodes = _{body.encode('utf-8', invalid: :replace, undef: :replace)}

        fixup_images(nodes)
      end
    else
      _p "(Cannot handle mime-type #{mime_type})"
    end
  end
end
