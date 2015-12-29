helpers do
  # update and restore an svn checkout to a clean state
  def svn_reset(repos)
    path = File.realpath(repos).untaint
    out, err, rc = Open3.capture3 'svn', 'cleanup', path
    out, err, rc = Open3.capture3 'svn', 'revert', '--recursive', path
    out, err, rc = Open3.capture3 'svn', 'status', path
    File.unlink *out.scan(/^\?\s+(.*)/).flatten.map(&:untaint)
    out, err, rc = Open3.capture3 'svn', 'update', path
  end
end
