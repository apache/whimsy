
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

  def svn *args
    args << svnauth if %(checkout update commit).include? args.first
    _.system! 'svn', *args
  end

  def svnauth
    [
      '--non-interactive', 
      '--no-auth-cache',
      '--username', env.user.untaint,
      '--password', env.password.untaint
    ]
  end

  def template(name)
    path = File.expand_path("../templates/#{name}", __FILE__.untaint)
    ERB.new(File.read(path.untaint).untaint).result(binding)
  end
end
