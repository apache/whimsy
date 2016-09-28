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
end
