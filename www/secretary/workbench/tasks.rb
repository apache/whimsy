
class Wunderbar::JsonBuilder
  def task(title, &block)
    if not @task
      # dry run: collect up a list of tasks
      @_target[:tasklist] ||= []
      @_target[:tasklist] << {title: title, form: []}

      block.call
    elsif @task == title
      # actual run
      block.call
      @task = nil
    end
  end

  def _input *args
    return if @task
    @_target[:tasklist].last[:form] << ['input', '', *args]
  end

  def _textarea *args
    return if @task
    @_target[:tasklist].last[:form] << ['textarea', *args]
  end

  def _message mail
    if @task
      super
    else
      @_target[:tasklist].last[:form] << ['textarea', mail.to_s.strip, rows: 20]
    end
  end

  def form &block
    block.call
  end

  def complete &block
    return unless @task

    if block.arity == 1
      Dir.mktmpdir do |dir|
        block.call dir
      end
    else
      block.call
    end
  end

  def _transcript *args
    return unless @task
    super
  end

  def _backtrace *args
    return unless @task
    super
  end

  # invoke svn using library method
  # assumes correct ordering of parameters
  def svn!(command, path, options={})
    options[:env] = env if env.password and %(checkout update commit).include?(command)
    ASF::SVN.svn_!(command, path, _, options)
  end

  # Commit new file(s) and update associated index
  # e.g. add ccla.pdf, ccla.pdf.asc to documents/cclas/xyz/ and update officers/cclas.txt
  # Parameters:
  # index_dir - SVN alias of directory containing the index (e.g. foundation or officers)
  # index_name - name of index file to update (e.g. cclas.txt)
  # docdir - SVN alias for document directory (e.g. cclas)
  # docname - document name (as per email)
  # docsig - document signature (as per email - may be null)
  # outfilename - name of output file (without extension)
  # outfileext - output file extension (of main file)
  # emessage - the email message
  # svnmessage - the svn commit message
  # block - the block which is passed the contents of the index file to be updated
  def svn_multi(index_dir, index_name, docdir, docname, docsig, outfilename, outfileext, emessage, svnmessage, &block)
    rc = nil
    Dir.mktmpdir do |tmpdir|

      rc = ASF::SVN.multiUpdate_(ASF::SVN.svnpath!(index_dir, index_name), svnmessage, env, _,{tmpdir: tmpdir}) do |text|

      extras = []
      # write the attachments as file(s)
      dest = emessage.write_att(tmpdir, docname, docsig)
      Wunderbar.warn dest.inspect

      if dest.size > 1 # write to a container directory
        unless outfilename =~ /\A[a-zA-Z][-.\w]+\z/ # previously done by write_svn
          raise IOError.new("invalid filename: #{outfilename}")
        end
        container = ASF::SVN.svnpath!(docdir, outfilename)
        extras << ['mkdir', container]
        dest.each do |name, file, content_type|
          if docdir == 'iclas' && outfileext # special processing for output name
            if name == docname
              name = "icla%s" % outfileext
            elsif name == docsig
              name = "icla%s.asc" % outfileext
            else
              Wunderbar.warn "Cannot recognise #{name} as #{docname} or #{docsig}"
            end
          end
          outpath = File.join(container, name)
          # N.B. file cannot exist here, because the directory was created as part of the same commit
          extras << ['put', file, outpath]
          extras << ['propset', 'svn:mime-type', content_type, outpath]
        end
      else
        _name, file, content_type = dest.flatten
        outpath = ASF::SVN.svnpath!(docdir,"#{outfilename}#{outfileext}")
        # TODO does it matter that the revision is not known?
        if ASF::SVN.exist?(outpath, nil, env)
          raise IOError.new("#{outpath} already exists!")
        else
          extras << ['put', file, outpath]
          extras << ['propset', 'svn:mime-type', content_type, outpath]
        end
      end

      text = yield text # update the index

      [text, extras]
    end

   end
   rc
  end

  def template(name)
    path = File.expand_path(File.join("..", "templates", name), __FILE__)
    ERB.new(File.read(path)).result(binding)
  end
end
