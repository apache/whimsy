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

helpers do
  # replace inline images (cid:) with references to attachments
  def fixup_images(node)
    if Wunderbar::Node === node
      if node.name == 'img'
        if node.attrs['src'] and node.attrs['src'].to_s.start_with? 'cid:'
          node.attrs['src'].value = node.attrs['src'].to_s.sub('cid:', '')
        end
      else
        fixup_images(node.search('img'))
      end
    elsif Array === node
      node.each {|child| fixup_images(child)}
    end
  end
end


class Wunderbar::JsonBuilder
  #
  # extract/verify project (set @pmc and @podling)
  #

  def _extract_project
    if @project and not @project.empty?
      @pmc = ASF::Committee[@project]

      if not @pmc
        @podling = ASF::Podling.find(@project)

        if @podling and not %w(graduated retired).include? @podling.status
          @pmc = ASF::Committee['incubator']

          unless @podling.private_mail_list
            _info "#{@project} mailing lists have not yet been set up"
            @podling = nil 
          end
        end
      end

      if not @pmc
        _warn "#{@project} is not an active PMC or podling"
      end
    end
  end

  # update the status of a message
  def _status(status_text)
    message = Mailbox.find(@message)
    message.headers[:secmail] ||= {}
    message.headers[:secmail][:status] = status_text
    message.write_headers
    _headers message.headers
  end
end
