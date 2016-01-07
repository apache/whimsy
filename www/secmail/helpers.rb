helpers do
  # update and restore an svn checkout to a clean state
  def svn_reset(repos)
    path = File.realpath(repos).untaint
    out, err, rc = Open3.capture3 'svn', 'cleanup', path
    out, err, rc = Open3.capture3 'svn', 'revert', '--recursive', path
    out, err, rc = Open3.capture3 'svn', 'status', path
    FileUtils.rm_rf out.scan(/^\?\s+(.*)/).flatten.map(&:untaint)
    out, err, rc = Open3.capture3 'svn', 'update', path
  end

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
