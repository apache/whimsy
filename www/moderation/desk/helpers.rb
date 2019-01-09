helpers do
  # replace inline images (cid:) with references to attachments
  def fixup_images(node)
    if Wunderbar::Node === node
      if node.name == 'img'
        src = node.attrs['src'] 
        if src 
          if src.to_s.start_with? 'cid:'
            src.value = src.to_s.sub('cid:', '')
          else # src.to_s.start_with? 'http' # Don't allow access to remote images
            src.value='../../transparent.png'
          end
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

  # update the status of a message
  def _status(status_text)
    message = Mailbox.find(@message)
    message.headers[:secmail] ||= {}
    message.headers[:secmail][:status] = status_text
    message.write_headers
    _headers message.headers
  end
end
