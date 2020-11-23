helpers do
  # replace inline images (cid:) with references to attachments
  def fixup_images(node)
    if node.is_a? Wunderbar::Node
      if node.name == 'img'
        if node.attrs['src'] and node.attrs['src'].to_s.start_with? 'cid:'
          node.attrs['src'].value = node.attrs['src'].to_s.sub('cid:', '')
        end
      else
        fixup_images(node.search('img'))
      end
    elsif node.is_a? Array
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

class String
  # fix encoding errors
  def fix_encoding
    result = self

    if encoding == Encoding::BINARY
      result = encode('utf-8', invalid: :replace, undef: :replace)
    end

    result
  end
end
